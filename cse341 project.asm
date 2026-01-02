; filepath: f:\Poralekha\cse341\Smart-Classroom-Attendance-System\projectcode.asm
.MODEL SMALL
.STACK 100H

.DATA
; ==================== SYSTEM CONSTANTS ====================
MAX_STUDENTS     EQU 10
LATE_THRESHOLD   EQU 91      ; ~5 seconds (18.2 ticks/sec)
BUFFER_TIME      EQU 182     ; ~10 seconds for undo security
UNDO_TIME_LIMIT  EQU 546     ; ~30 seconds (18.2 ticks/sec) for undo without confirmation
STACK_SIZE       EQU 20

; ==================== AUTHENTICATION DATA ====================
teacher_a_pass   DB "admin1", 0
teacher_b_pass   DB "admin2", 0
input_pass       DB 10 DUP(0)
current_teacher  DB 0        ; 1 = Teacher A, 2 = Teacher B
login_attempts   DB 3

; ==================== SECTION A DATA ====================
section_a_ids    DB 101, 102, 103, 104, 105, 106, 107, 108, 109, 110
section_a_status DB 10 DUP(0)    ; 0=Absent, 1=Present, 2=Late
section_a_total_present DB 10 DUP(0)
section_a_total_absent  DB 10 DUP(0)
section_a_absent_days   DB 100 DUP(0)  ; 10 students x 10 days
section_a_viva_marks    DB 10 DUP(0)
section_a_attend_marks  DB 10 DUP(0)
section_a_grades        DB 10 DUP(0)   ; 1=Collegiate, 2=Non-Collegiate, 3=Dis-Collegiate

; ==================== SECTION B DATA ====================
section_b_ids    DB 201, 202, 203, 204, 205, 206, 207, 208, 209, 210
section_b_status DB 10 DUP(0)
section_b_total_present DB 10 DUP(0)
section_b_total_absent  DB 10 DUP(0)
section_b_absent_days   DB 100 DUP(0)
section_b_viva_marks    DB 10 DUP(0)
section_b_attend_marks  DB 10 DUP(0)
section_b_grades        DB 10 DUP(0)

; ==================== POINTERS (Set based on login) ====================
current_ids      DW ?
current_status   DW ?
current_present  DW ?
current_absent   DW ?
current_abs_days DW ?
current_viva     DW ?
current_att_mrks DW ?
current_grades   DW ?

; ==================== UNDO/REDO STACK ====================
undo_stack_id    DB STACK_SIZE DUP(0)
undo_stack_stat  DB STACK_SIZE DUP(0)
undo_stack_time  DW STACK_SIZE DUP(0)
undo_stack_ptr   DB 0
redo_stack_id    DB STACK_SIZE DUP(0)
redo_stack_stat  DB STACK_SIZE DUP(0)
redo_stack_ptr   DB 0

; ==================== SESSION DATA ====================
session_start    DW 0
current_day      DB 1
total_classes    DB 10
roll_call_start  DW 0
roll_call_end_time DW 0     ; Time when roll call completed

; ==================== ACTIVE POOL FOR VIVA ====================
active_pool      DB 10 DUP(0)
active_count     DB 0

; ==================== SORTED ARRAY FOR SEARCH ====================
sorted_ids       DB 10 DUP(0)
sorted_indices   DB 10 DUP(0)

; ==================== UI MESSAGES ====================
border_msg       DB 0Dh, 0Ah, "========================================================================", 0Dh, 0Ah, "$"
welcome_msg      DB "          SMART CLASSROOM ATTENDANCE SYSTEM", 0Dh, 0Ah, "$"
login_msg        DB 0Dh, 0Ah, "Enter Password: $"
login_fail_msg   DB 0Dh, 0Ah, "Invalid Password! Attempts left: $"
login_success_a  DB 0Dh, 0Ah, "Welcome Teacher A - Section A Loaded", 0Dh, 0Ah, "$"
login_success_b  DB 0Dh, 0Ah, "Welcome Teacher B - Section B Loaded", 0Dh, 0Ah, "$"
login_locked     DB 0Dh, 0Ah, "System Locked! Too many failed attempts.", 0Dh, 0Ah, "$"

menu_msg         DB 0Dh, 0Ah, "===================== MAIN MENU =====================", 0Dh, 0Ah
                 DB "[1] Smart Roll Call", 0Dh, 0Ah
                 DB "[2] Undo Last Action", 0Dh, 0Ah
                 DB "[3] Redo Last Undo", 0Dh, 0Ah
                 DB "[4] View Eligibility & Grades", 0Dh, 0Ah
                 DB "[5] Search Student", 0Dh, 0Ah
                 DB "[6] Random Viva Selection", 0Dh, 0Ah
                 DB "[7] Enter Viva Marks", 0Dh, 0Ah
                 DB "[8] View All Students", 0Dh, 0Ah
                 DB "[9] Next Day", 0Dh, 0Ah
                 DB "[0] Logout & Exit", 0Dh, 0Ah
                 DB "Choice: $"

; Roll Call Messages
roll_prompt      DB " - Enter 1 (Present) or 0 (Absent) [5 sec timeout]: $"
roll_present     DB " - Marked PRESENT", 0Dh, 0Ah, "$"
roll_absent      DB " - Marked ABSENT", 0Dh, 0Ah, "$"
roll_late        DB " - Marked LATE (No input)", 0Dh, 0Ah, "$"
roll_start_msg   DB 0Dh, 0Ah, "Roll Call Started. You have 5 seconds per student.", 0Dh, 0Ah, "$"
roll_end_msg     DB 0Dh, 0Ah, "Roll Call Complete!", 0Dh, 0Ah, "$"
roll_student_id  DB 0Dh, 0Ah, "Student ID: $"

; Undo/Redo Messages
undo_success     DB 0Dh, 0Ah, "Status changed successfully!", 0Dh, 0Ah, "$"
undo_empty       DB 0Dh, 0Ah, "Nothing to Undo!", 0Dh, 0Ah, "$"
undo_expired     DB 0Dh, 0Ah, "WARNING: Buffer time expired! Re-authenticate to proceed.", 0Dh, 0Ah, "$"
undo_id_prompt   DB 0Dh, 0Ah, "Enter Student ID to change status: $"
undo_status_prompt DB 0Dh, 0Ah, "Select new status: [0] Absent, [1] Present, [2] Late: $"
undo_invalid_id  DB 0Dh, 0Ah, "Invalid Student ID!", 0Dh, 0Ah, "$"
undo_invalid_status DB 0Dh, 0Ah, "Invalid status! Please enter 0, 1, or 2.", 0Dh, 0Ah, "$"
undo_confirm_msg DB 0Dh, 0Ah, "WARNING: More than 30 seconds since roll call. Continue? [Y/N]: $"
undo_cancelled   DB 0Dh, 0Ah, "Undo cancelled.", 0Dh, 0Ah, "$"
redo_success     DB 0Dh, 0Ah, "Redo Successful!", 0Dh, 0Ah, "$"
redo_empty       DB 0Dh, 0Ah, "Nothing to Redo!", 0Dh, 0Ah, "$"
reauth_prompt    DB "Enter password to confirm: $"
reauth_fail      DB 0Dh, 0Ah, "Re-authentication failed! Action cancelled.", 0Dh, 0Ah, "$"
logout_success_msg DB 0Dh, 0Ah, "Logout successful!", 0Dh, 0Ah, "$"
logout_msg       DB 0Dh, 0Ah, "Please enter another teacher's password: $"
logout_invalid   DB 0Dh, 0Ah, "Invalid Password! Please try again.", 0Dh, 0Ah, "$"

; Search Messages
search_prompt    DB 0Dh, 0Ah, "Enter Student ID to search: $"
search_found     DB 0Dh, 0Ah, "=== STUDENT RECORD FOUND ===", 0Dh, 0Ah, "$"
search_not_found DB 0Dh, 0Ah, "Student not found!", 0Dh, 0Ah, "$"
status_label     DB "Today's Status: $"
present_str      DB "PRESENT", 0Dh, 0Ah, "$"
absent_str       DB "ABSENT", 0Dh, 0Ah, "$"
late_str         DB "LATE", 0Dh, 0Ah, "$"
total_pres_lbl   DB "Total Present: $"
total_abs_lbl    DB "Total Absent: $"
viva_marks_lbl   DB "Viva Marks: $"
attend_marks_lbl DB "Attendance Marks: $"
grade_lbl        DB "Grade: $"
collegiate_str   DB "COLLEGIATE", 0Dh, 0Ah, "$"
non_colleg_str   DB "NON-COLLEGIATE", 0Dh, 0Ah, "$"
dis_colleg_str   DB "DIS-COLLEGIATE", 0Dh, 0Ah, "$"
absent_days_lbl  DB "Absent on Days: $"

; Viva Messages
viva_select_msg  DB 0Dh, 0Ah, "=== RANDOM VIVA SELECTION ===", 0Dh, 0Ah, "$"
viva_no_present  DB "No students present for viva!", 0Dh, 0Ah, "$"
viva_all_done    DB 0Dh, 0Ah, "All present students have viva marks!", 0Dh, 0Ah, "$"
viva_selected    DB "Selected Student ID: $"
viva_mark_prompt DB 0Dh, 0Ah, "Enter Viva Mark (0-10): $"
viva_saved       DB 0Dh, 0Ah, "Viva mark saved!", 0Dh, 0Ah, "$"
viva_another     DB 0Dh, 0Ah, "Do you want to select another student? (Y/N): $"
manual_viva_id   DB 0Dh, 0Ah, "Enter Student ID for Viva Marks: $"
viva_invalid_id  DB 0Dh, 0Ah, "Invalid Student ID! Please try again.", 0Dh, 0Ah, "$"

; Eligibility Messages
elig_header      DB 0Dh, 0Ah, "=== ELIGIBILITY & GRADES REPORT ===", 0Dh, 0Ah, "$"
elig_id_lbl      DB "ID: $"
elig_pct_lbl     DB " | Attendance: $"
elig_pct_sym     DB "% | $"

; View All Messages
view_header      DB 0Dh, 0Ah, "=== ALL STUDENTS STATUS ===", 0Dh, 0Ah
                 DB "ID   | Status  | Present | Absent | Grade | AttM | VivaM | Total", 0Dh, 0Ah
                 DB "----------------------------------------------------------------------", 0Dh, 0Ah, "$"

; Day Messages
day_msg          DB 0Dh, 0Ah, "Current Day: $"
next_day_msg     DB 0Dh, 0Ah, "Advanced to next day. Statuses reset.", 0Dh, 0Ah, "$"

newline          DB 0Dh, 0Ah, "$"
space_str        DB "  $"
pipe_str         DB " | $"

; Temp buffers
input_buffer     DB 10 DUP(0)
num_buffer       DB 6 DUP(0)
temp_id          DB 0
timeout_start    DW 0

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    
    ; Display welcome screen
    CALL display_welcome
    
    ; Authentication
    CALL authenticate
    CMP current_teacher, 0
    JE exit_program
    
    ; Setup memory partition based on teacher
    CALL setup_partition
    
    ; Get session start time
    MOV AH, 00h
    INT 1Ah
    MOV session_start, DX

main_menu_loop:
    ; Display menu
    LEA DX, menu_msg
    MOV AH, 09h
    INT 21h
    
    ; Get choice
    MOV AH, 01h
    INT 21h
    
    CMP AL, '1'
    JE do_roll_call
    CMP AL, '2'
    JE do_undo
    CMP AL, '3'
    JE do_redo
    CMP AL, '4'
    JE do_eligibility
    CMP AL, '5'
    JE do_search
    CMP AL, '6'
    JE do_random_viva
    CMP AL, '7'
    JE do_manual_viva
    CMP AL, '8'
    JE do_view_all
    CMP AL, '9'
    JE do_next_day
    CMP AL, '0'
    JE logout_handler
    JMP main_menu_loop

do_roll_call:
    CALL smart_roll_call
    JMP main_menu_loop

do_undo:
    CALL undo_action
    JMP main_menu_loop

do_redo:
    CALL redo_action
    JMP main_menu_loop

do_eligibility:
    CALL calc_eligibility
    JMP main_menu_loop

do_search:
    CALL search_student
    JMP main_menu_loop

do_random_viva:
    CALL random_viva_select
    JMP main_menu_loop

do_manual_viva:
    CALL enter_viva_marks
    JMP main_menu_loop

do_view_all:
    CALL view_all_students
    JMP main_menu_loop

do_next_day:
    CALL advance_day
    JMP main_menu_loop

logout_handler:
    ; Display logout success message
    LEA DX, logout_success_msg
    MOV AH, 09h
    INT 21h

logout_retry:
    ; Display message asking for another teacher's password
    LEA DX, logout_msg
    MOV AH, 09h
    INT 21h
    
    ; Read password
    LEA SI, input_pass
    MOV CX, 0
    
logout_read_pass:
    MOV AH, 01h
    INT 21h
    CMP AL, 0Dh          ; Enter key
    JE logout_check_password
    MOV [SI], AL
    INC SI
    INC CX
    CMP CX, 6
    JL logout_read_pass

logout_check_password:
    MOV BYTE PTR [SI], 0  ; Null terminate
    
    ; Compare with Teacher A password
    LEA SI, input_pass
    LEA DI, teacher_a_pass
    CALL str_compare
    CMP AX, 1
    JE logout_teacher_a
    
    ; Compare with Teacher B password
    LEA SI, input_pass
    LEA DI, teacher_b_pass
    CALL str_compare
    CMP AX, 1
    JE logout_teacher_b
    
    ; Failed - show error and retry
    LEA DX, logout_invalid
    MOV AH, 09h
    INT 21h
    JMP logout_retry
    
logout_teacher_a:
    MOV current_teacher, 1
    LEA DX, login_success_a
    MOV AH, 09h
    INT 21h
    JMP logout_success
    
logout_teacher_b:
    MOV current_teacher, 2
    LEA DX, login_success_b
    MOV AH, 09h
    INT 21h
    
logout_success:
    ; Setup memory partition for new teacher
    CALL setup_partition
    
    ; Get new session start time
    MOV AH, 00h
    INT 1Ah
    MOV session_start, DX
    
    ; Continue to menu
    JMP main_menu_loop

exit_program:
    MOV AX, 4C00h
    INT 21h
MAIN ENDP

; ==================== DISPLAY WELCOME ====================
display_welcome PROC
    LEA DX, border_msg
    MOV AH, 09h
    INT 21h
    LEA DX, welcome_msg
    MOV AH, 09h
    INT 21h
    LEA DX, border_msg
    MOV AH, 09h
    INT 21h
    RET
display_welcome ENDP

; ==================== AUTHENTICATION (Feature 6) ====================
authenticate PROC
    MOV login_attempts, 3

auth_loop:
    CMP login_attempts, 0
    JE auth_locked
    
    LEA DX, login_msg
    MOV AH, 09h
    INT 21h
    
    ; Read password (hidden input)
    LEA SI, input_pass
    MOV CX, 0
    
read_pass_loop:
    MOV AH, 01h
    INT 21h
    CMP AL, 0Dh          ; Enter key
    JE check_password
    MOV [SI], AL
    INC SI
    INC CX
    CMP CX, 6
    JL read_pass_loop

check_password:
    MOV BYTE PTR [SI], 0  ; Null terminate
    
    ; Compare with Teacher A password
    LEA SI, input_pass
    LEA DI, teacher_a_pass
    CALL str_compare
    CMP AX, 1
    JE auth_teacher_a
    
    ; Compare with Teacher B password
    LEA SI, input_pass
    LEA DI, teacher_b_pass
    CALL str_compare
    CMP AX, 1
    JE auth_teacher_b
    
    ; Failed
    DEC login_attempts
    LEA DX, login_fail_msg
    MOV AH, 09h
    INT 21h
    
    MOV AL, login_attempts
    ADD AL, '0'
    MOV DL, AL
    MOV AH, 02h
    INT 21h
    
    JMP auth_loop

auth_teacher_a:
    MOV current_teacher, 1
    LEA DX, login_success_a
    MOV AH, 09h
    INT 21h
    RET

auth_teacher_b:
    MOV current_teacher, 2
    LEA DX, login_success_b
    MOV AH, 09h
    INT 21h
    RET

auth_locked:
    LEA DX, login_locked
    MOV AH, 09h
    INT 21h
    MOV current_teacher, 0
    RET
authenticate ENDP

; ==================== STRING COMPARE ====================
str_compare PROC
    ; SI = string 1, DI = string 2
    ; Returns AX = 1 if equal, 0 if not
cmp_loop:
    MOV AL, [SI]
    MOV BL, [DI]
    CMP AL, BL
    JNE not_equal
    CMP AL, 0
    JE equal
    INC SI
    INC DI
    JMP cmp_loop
equal:
    MOV AX, 1
    RET
not_equal:
    MOV AX, 0
    RET
str_compare ENDP

; ==================== SETUP PARTITION (Feature 6) ====================
setup_partition PROC
    CMP current_teacher, 1
    JE setup_section_a
    
    ; Section B
    LEA AX, section_b_ids
    MOV current_ids, AX
    LEA AX, section_b_status
    MOV current_status, AX
    LEA AX, section_b_total_present
    MOV current_present, AX
    LEA AX, section_b_total_absent
    MOV current_absent, AX
    LEA AX, section_b_absent_days
    MOV current_abs_days, AX
    LEA AX, section_b_viva_marks
    MOV current_viva, AX
    LEA AX, section_b_attend_marks
    MOV current_att_mrks, AX
    LEA AX, section_b_grades
    MOV current_grades, AX
    RET

setup_section_a:
    LEA AX, section_a_ids
    MOV current_ids, AX
    LEA AX, section_a_status
    MOV current_status, AX
    LEA AX, section_a_total_present
    MOV current_present, AX
    LEA AX, section_a_total_absent
    MOV current_absent, AX
    LEA AX, section_a_absent_days
    MOV current_abs_days, AX
    LEA AX, section_a_viva_marks
    MOV current_viva, AX
    LEA AX, section_a_attend_marks
    MOV current_att_mrks, AX
    LEA AX, section_a_grades
    MOV current_grades, AX
    RET
setup_partition ENDP

; ==================== WAIT FOR INPUT WITH TIMEOUT ====================
wait_for_input_timeout PROC
    ; Returns AL = input character ('1', '0') or 0 if timeout
    ; Timeout is 5 seconds (LATE_THRESHOLD ticks)
    
    ; Get start time
    MOV AH, 00h
    INT 1Ah
    MOV timeout_start, DX
    
wait_loop:
    ; Check if keyboard has input available (non-blocking)
    MOV AH, 01h
    INT 16h
    JNZ input_available
    
    ; Check timeout
    MOV AH, 00h
    INT 1Ah
    MOV AX, DX
    SUB AX, timeout_start
    CMP AX, LATE_THRESHOLD
    JA timeout_reached
    
    ; Small delay to avoid busy waiting
    PUSH CX
    MOV CX, 1000
delay_loop:
    LOOP delay_loop
    POP CX
    
    JMP wait_loop

input_available:
    ; Read the character from buffer
    MOV AH, 00h
    INT 16h
    
    ; Check if it's '1' or '0'
    CMP AL, '1'
    JE valid_input
    CMP AL, '0'
    JE valid_input
    
    ; Ignore Enter and other invalid keys, continue waiting
    CMP AL, 0Dh
    JE wait_loop
    
    ; For other keys, continue waiting
    JMP wait_loop

valid_input:
    RET

timeout_reached:
    ; Clear any pending keyboard input
    MOV AH, 01h
    INT 16h
    JZ timeout_done
    ; Remove the key from buffer
    MOV AH, 00h
    INT 16h
    JMP timeout_done

timeout_done:
    MOV AL, 0
    RET
wait_for_input_timeout ENDP

; ==================== SMART ROLL CALL (Feature 1) ====================
smart_roll_call PROC
    LEA DX, roll_start_msg
    MOV AH, 09h
    INT 21h
    
    ; Loop through all students
    MOV CX, MAX_STUDENTS
    MOV BX, 0
    MOV SI, current_ids

roll_call_loop:
    PUSH CX
    PUSH BX
    PUSH SI
    
    ; Display student ID
    LEA DX, roll_student_id
    MOV AH, 09h
    INT 21h
    
    MOV AL, [SI+BX]
    CALL print_number
    
    ; Display prompt
    LEA DX, roll_prompt
    MOV AH, 09h
    INT 21h
    
    ; Wait for input with 5 second timeout
    CALL wait_for_input_timeout
    
    ; AL contains input: '1' = present, '0' = absent, 0 = timeout (late)
    ; Save input character in DL
    MOV DL, AL
    
    POP SI
    POP BX
    PUSH BX
    PUSH SI
    
    ; Get student ID for undo stack
    MOV AL, [SI+BX]
    MOV temp_id, AL
    
    ; Find student index
    CALL find_student_index
    
    ; Get current status for undo (before changing)
    MOV SI, current_status
    ADD SI, BX
    MOV AH, [SI]        ; Previous status in AH
    
    ; Push to undo stack (AL = student ID, AH = previous status)
    PUSH DX              ; Save input
    MOV AL, temp_id
    CALL push_undo_stack
    POP DX               ; Restore input
    
    ; Check input (now in DL)
    MOV AL, DL
    CMP AL, '1'
    JE mark_present
    
    CMP AL, '0'
    JE mark_absent
    
    ; Timeout - mark as late
    JMP mark_late_timeout

mark_present:
    MOV SI, current_status
    ADD SI, BX
    MOV BYTE PTR [SI], 1
    
    ; Increment total present
    MOV SI, current_present
    ADD SI, BX
    INC BYTE PTR [SI]
    
    LEA DX, roll_present
    MOV AH, 09h
    INT 21h
    JMP next_student

mark_absent:
    MOV SI, current_status
    ADD SI, BX
    MOV BYTE PTR [SI], 0
    
    ; Increment total absent
    MOV SI, current_absent
    ADD SI, BX
    INC BYTE PTR [SI]
    
    ; Record absent day
    PUSH BX
    MOV SI, current_abs_days
    MOV AL, BL
    MOV CL, 10
    MUL CL              ; AL = student_index * 10
    ADD SI, AX
    XOR AH, AH
    MOV AL, current_day
    DEC AL
    ADD SI, AX
    MOV AL, current_day
    MOV [SI], AL
    POP BX
    
    LEA DX, roll_absent
    MOV AH, 09h
    INT 21h
    JMP next_student

mark_late_timeout:
    MOV SI, current_status
    ADD SI, BX
    MOV BYTE PTR [SI], 2
    
    ; Still count as present for attendance
    MOV SI, current_present
    ADD SI, BX
    INC BYTE PTR [SI]
    
    LEA DX, roll_late
    MOV AH, 09h
    INT 21h

next_student:
    POP SI
    POP BX
    POP CX
    INC BX
    DEC CX
    JNZ roll_call_loop

roll_call_end:
    ; Save roll call end time
    MOV AH, 00h
    INT 1Ah
    MOV roll_call_end_time, DX
    
    ; Calculate grades for all students after roll call
    CALL calculate_all_grades
    
    LEA DX, roll_end_msg
    MOV AH, 09h
    INT 21h
    RET
smart_roll_call ENDP

; ==================== MARK ABSENT REMAINING ====================
mark_absent_remaining PROC
    MOV CX, MAX_STUDENTS
    MOV BX, 0
    MOV SI, current_status
    MOV DI, current_absent
    
mark_abs_loop:
    CMP BYTE PTR [SI+BX], 0
    JNE skip_absent_mark
    
    ; Increment absent count
    PUSH SI
    MOV SI, DI
    ADD SI, BX
    INC BYTE PTR [SI]
    POP SI
    
    ; Record absent day
    PUSH BX
    PUSH CX
    MOV SI, current_abs_days
    MOV AL, BL
    MOV CL, 10
    MUL CL              ; AL = student_index * 10
    ADD SI, AX
    XOR AH, AH
    MOV AL, current_day
    DEC AL
    ADD SI, AX
    MOV AL, current_day
    MOV [SI], AL
    POP CX
    POP BX

skip_absent_mark:
    INC BX
    LOOP mark_abs_loop
    RET
mark_absent_remaining ENDP

; ==================== FIND STUDENT INDEX ====================
find_student_index PROC
    ; Input: temp_id, Output: BX = index or 0xFFFF if not found
    MOV SI, current_ids
    MOV CX, MAX_STUDENTS
    MOV BX, 0
    
find_loop:
    MOV AL, [SI+BX]
    CMP AL, temp_id
    JE found_student
    INC BX
    LOOP find_loop
    
    MOV BX, 0FFFFh
    RET

found_student:
    RET
find_student_index ENDP

; ==================== READ NUMBER ====================
read_number PROC
    ; Reads up to 3-digit number, returns in AX
    XOR AX, AX
    XOR BX, BX
    MOV CX, 3
    
read_num_loop:
    PUSH AX
    MOV AH, 01h
    INT 21h
    
    CMP AL, 0Dh
    JE read_num_done
    CMP AL, '0'
    JL read_num_done
    CMP AL, '9'
    JG read_num_done
    
    SUB AL, '0'
    MOV BL, AL
    POP AX
    
    ; AX = AX * 10 + digit
    MOV DX, 10
    MUL DX
    ADD AX, BX
    
    LOOP read_num_loop
    RET

read_num_done:
    POP AX
    RET
read_number ENDP

; ==================== READ TWO DIGIT NUMBER ====================
read_two_digit_number PROC
    ; Reads up to 2-digit number, returns in AL (0-99)
    XOR AX, AX
    XOR BX, BX
    MOV CX, 2
    
read_two_loop:
    PUSH AX
    MOV AH, 01h
    INT 21h
    
    CMP AL, 0Dh
    JE read_two_done
    CMP AL, '0'
    JL read_two_done
    CMP AL, '9'
    JG read_two_done
    
    SUB AL, '0'
    MOV BL, AL
    POP AX
    
    ; AX = AX * 10 + digit
    MOV DX, 10
    MUL DX
    ADD AX, BX
    
    LOOP read_two_loop
    RET

read_two_done:
    POP AX
    RET
read_two_digit_number ENDP

; ==================== PUSH UNDO STACK (Feature 2) ====================
push_undo_stack PROC
    ; AL = student ID, AH = previous status
    PUSH BX
    XOR BH, BH
    MOV BL, undo_stack_ptr
    
    MOV undo_stack_id[BX], AL
    MOV undo_stack_stat[BX], AH
    
    ; Store timestamp
    PUSH AX
    MOV AH, 00h
    INT 1Ah
    SHL BX, 1
    MOV undo_stack_time[BX], DX
    POP AX
    
    INC undo_stack_ptr
    CMP undo_stack_ptr, STACK_SIZE
    JL push_done
    MOV undo_stack_ptr, 0  ; Wrap around
    
push_done:
    ; Clear redo stack on new action
    MOV redo_stack_ptr, 0
    POP BX
    RET
push_undo_stack ENDP

; ==================== UNDO ACTION (Feature 2) ====================
undo_action PROC
    ; Check if roll call has been completed
    CMP roll_call_end_time, 0
    JE no_roll_call_done
    
    ; Check time since roll call ended
    MOV AH, 00h
    INT 1Ah
    MOV AX, DX
    SUB AX, roll_call_end_time
    CMP AX, UNDO_TIME_LIMIT
    JA undo_needs_confirm
    
    ; Within 30 seconds, proceed normally
    JMP proceed_undo

undo_needs_confirm:
    ; More than 30 seconds, show confirmation
    LEA DX, undo_confirm_msg
    MOV AH, 09h
    INT 21h
    
    ; Read confirmation
    MOV AH, 01h
    INT 21h
    
    ; Check if user confirmed (Y or y)
    CMP AL, 'Y'
    JE proceed_undo
    CMP AL, 'y'
    JE proceed_undo
    
    ; User cancelled
    LEA DX, undo_cancelled
    MOV AH, 09h
    INT 21h
    RET

proceed_undo:
    ; Prompt for student ID
    LEA DX, undo_id_prompt
    MOV AH, 09h
    INT 21h
    
    CALL read_number
    MOV temp_id, AL
    
    ; Validate student ID
    CALL find_student_index
    CMP BX, 0FFFFh
    JE undo_invalid_student
    
    ; Get current status before changing
    MOV SI, current_status
    ADD SI, BX
    MOV AH, [SI]        ; Current status for undo stack
    
    ; Save to undo stack before changing
    PUSH AX
    MOV AL, temp_id
    CALL push_undo_stack
    POP AX
    
    ; Prompt for new status
    LEA DX, undo_status_prompt
    MOV AH, 09h
    INT 21h
    
    ; Read status choice
    MOV AH, 01h
    INT 21h
    
    ; Validate status input
    CMP AL, '0'
    JE set_absent
    CMP AL, '1'
    JE set_present
    CMP AL, '2'
    JE set_late
    
    ; Invalid status
    LEA DX, undo_invalid_status
    MOV AH, 09h
    INT 21h
    RET

no_roll_call_done:
    ; No roll call done yet, proceed normally
    JMP proceed_undo

set_absent:
    MOV AL, 0
    JMP update_status

set_present:
    MOV AL, 1
    JMP update_status

set_late:
    MOV AL, 2

update_status:
    ; Save current status for count update
    MOV SI, current_status
    ADD SI, BX
    MOV AH, [SI]        ; Old status in AH
    MOV [SI], AL        ; New status in AL
    
    ; Update present/absent counts based on status change
    ; AL = new status, AH = old status
    CMP AL, 0
    JE new_status_absent
    ; New status is present (1) or late (2)
    CMP AH, 0
    JE change_to_present
    ; Was already present/late, check if changing between present/late
    CMP AL, AH
    JE no_count_change
    ; Changing between present and late, no count change needed
    JMP no_count_change

change_to_present:
    ; Was absent, now present/late - increment present, decrement absent
    MOV SI, current_present
    ADD SI, BX
    INC BYTE PTR [SI]
    MOV SI, current_absent
    ADD SI, BX
    DEC BYTE PTR [SI]
    JMP no_count_change

new_status_absent:
    ; New status is absent
    CMP AH, 0
    JE no_count_change  ; Was already absent, no change
    ; Was present/late, now absent - decrement present, increment absent
    MOV SI, current_present
    ADD SI, BX
    DEC BYTE PTR [SI]
    MOV SI, current_absent
    ADD SI, BX
    INC BYTE PTR [SI]

no_count_change:
    LEA DX, undo_success
    MOV AH, 09h
    INT 21h
    RET

undo_invalid_student:
    LEA DX, undo_invalid_id
    MOV AH, 09h
    INT 21h
    RET
undo_action ENDP

; ==================== REDO ACTION (Feature 2) ====================
redo_action PROC
    CMP redo_stack_ptr, 0
    JE redo_empty_stack
    
    DEC redo_stack_ptr
    XOR BH, BH
    MOV BL, redo_stack_ptr
    
    ; Get ID from redo stack using register
    LEA SI, redo_stack_id
    ADD SI, BX
    MOV AL, [SI]
    MOV temp_id, AL
    
    ; Get status from redo stack
    LEA SI, redo_stack_stat
    ADD SI, BX
    MOV AH, [SI]
    PUSH AX
    
    CALL find_student_index
    POP AX
    
    ; Save current status before changing
    MOV SI, current_status
    ADD SI, BX
    MOV AL, [SI]        ; Current status in AL
    MOV [SI], AH        ; Restore status from redo stack (AH)
    
    ; Update present/absent counts based on status change
    ; AH = new status (from redo), AL = old status (current)
    CMP AH, 0
    JE redo_to_absent
    ; New status is present (1) or late (2)
    CMP AL, 0
    JE redo_from_absent_to_present
    ; Was already present/late, no change needed
    JMP redo_counts_done

redo_from_absent_to_present:
    ; Was absent, now present/late - increment present, decrement absent
    MOV SI, current_present
    ADD SI, BX
    INC BYTE PTR [SI]
    MOV SI, current_absent
    ADD SI, BX
    DEC BYTE PTR [SI]
    JMP redo_counts_done

redo_to_absent:
    ; New status is absent
    CMP AL, 0
    JE redo_counts_done  ; Was already absent, no change
    ; Was present/late, now absent - decrement present, increment absent
    MOV SI, current_present
    ADD SI, BX
    DEC BYTE PTR [SI]
    MOV SI, current_absent
    ADD SI, BX
    INC BYTE PTR [SI]

redo_counts_done:
    LEA DX, redo_success
    MOV AH, 09h
    INT 21h
    RET

redo_empty_stack:
    LEA DX, redo_empty
    MOV AH, 09h
    INT 21h
    RET
redo_action ENDP

; ==================== CALCULATE ELIGIBILITY (Feature 3) ====================
calc_eligibility PROC
    LEA DX, elig_header
    MOV AH, 09h
    INT 21h
    
    MOV CX, MAX_STUDENTS
    MOV BX, 0
    
elig_loop:
    PUSH CX
    PUSH BX
    
    ; Print ID
    LEA DX, elig_id_lbl
    MOV AH, 09h
    INT 21h
    
    MOV SI, current_ids
    MOV AL, [SI+BX]
    CALL print_number
    
    ; Calculate percentage
    MOV SI, current_present
    XOR AH, AH
    MOV AL, [SI+BX]
    MOV CL, 100
    MUL CL              ; AX = present * 100
    
    XOR DX, DX
    MOV CL, total_classes
    DIV CX              ; AX = percentage
    
    PUSH AX             ; Save percentage
    
    ; Print percentage
    LEA DX, elig_pct_lbl
    MOV AH, 09h
    INT 21h
    
    POP AX
    PUSH AX
    CALL print_number
    
    LEA DX, elig_pct_sym
    MOV AH, 09h
    INT 21h
    
    ; Determine grade and calculate attendance marks
    POP AX
    POP BX
    PUSH BX
    
    ; Calculate attendance marks (percentage / 20, max 5)
    PUSH AX
    XOR DX, DX
    MOV CX, 20
    DIV CX
    CMP AL, 5
    JLE att_mark_ok
    MOV AL, 5
att_mark_ok:
    MOV SI, current_att_mrks
    MOV [SI+BX], AL
    POP AX
    
    ; Determine grade
    MOV SI, current_grades
    CMP AX, 90
    JA grade_collegiate
    CMP AX, 75
    JA grade_non_collegiate
    
    ; Dis-Collegiate
    MOV BYTE PTR [SI+BX], 3
    LEA DX, dis_colleg_str
    JMP print_grade

grade_collegiate:
    MOV BYTE PTR [SI+BX], 1
    LEA DX, collegiate_str
    JMP print_grade

grade_non_collegiate:
    MOV BYTE PTR [SI+BX], 2
    LEA DX, non_colleg_str

print_grade:
    MOV AH, 09h
    INT 21h
    
    POP BX
    POP CX
    INC BX
    DEC CX
    JNZ elig_loop
    
    RET
calc_eligibility ENDP

; ==================== CALCULATE ALL GRADES ====================
calculate_all_grades PROC
    ; Calculate grades for all students without displaying
    MOV CX, MAX_STUDENTS
    MOV BX, 0
    
calc_grades_loop:
    PUSH CX
    PUSH BX
    
    ; Calculate attendance percentage
    MOV SI, current_present
    XOR AH, AH
    MOV AL, [SI+BX]
    MOV CL, 100
    MUL CL              ; AX = present * 100
    
    XOR DX, DX
    MOV CL, total_classes
    CMP CL, 0
    JE skip_grade_calc  ; Avoid division by zero
    DIV CX              ; AX = percentage
    
    ; Calculate attendance marks (percentage / 20, max 5)
    PUSH AX
    XOR DX, DX
    MOV CX, 20
    DIV CX
    CMP AL, 5
    JLE att_mark_ok2
    MOV AL, 5
att_mark_ok2:
    MOV SI, current_att_mrks
    MOV [SI+BX], AL
    POP AX
    
    ; Determine grade based on percentage
    MOV SI, current_grades
    CMP AX, 90
    JA set_collegiate
    CMP AX, 75
    JA set_non_collegiate
    
    ; Dis-Collegiate
    MOV BYTE PTR [SI+BX], 3
    JMP grade_calc_done

set_collegiate:
    MOV BYTE PTR [SI+BX], 1
    JMP grade_calc_done

set_non_collegiate:
    MOV BYTE PTR [SI+BX], 2

grade_calc_done:
    POP BX
    POP CX
    INC BX
    DEC CX
    JNZ calc_grades_loop
    RET

skip_grade_calc:
    POP BX
    POP CX
    INC BX
    DEC CX
    JNZ calc_grades_loop
    RET
calculate_all_grades ENDP

; ==================== SEARCH STUDENT (Feature 4) ====================
search_student PROC
    ; First, sort the IDs using Bubble Sort
    CALL bubble_sort_ids
    
    LEA DX, search_prompt
    MOV AH, 09h
    INT 21h
    
    CALL read_number
    MOV temp_id, AL
    
    ; Binary Search
    CALL binary_search
    CMP BX, 0FFFFh
    JE search_not_found_lbl
    
    ; Display found record
    LEA DX, search_found
    MOV AH, 09h
    INT 21h
    
    ; Status
    LEA DX, status_label
    MOV AH, 09h
    INT 21h
    
    MOV SI, current_status
    MOV AL, [SI+BX]
    CMP AL, 0
    JE show_absent
    CMP AL, 1
    JE show_present
    LEA DX, late_str
    JMP show_status
show_absent:
    LEA DX, absent_str
    JMP show_status
show_present:
    LEA DX, present_str
show_status:
    MOV AH, 09h
    INT 21h
    
    ; Total Present
    LEA DX, total_pres_lbl
    MOV AH, 09h
    INT 21h
    MOV SI, current_present
    MOV AL, [SI+BX]
    CALL print_number
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    ; Total Absent
    LEA DX, total_abs_lbl
    MOV AH, 09h
    INT 21h
    MOV SI, current_absent
    MOV AL, [SI+BX]
    CALL print_number
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    ; Absent Days
    LEA DX, absent_days_lbl
    MOV AH, 09h
    INT 21h
    
    PUSH BX
    MOV SI, current_abs_days
    MOV AL, BL
    MOV CL, 10
    MUL CL
    ADD SI, AX
    MOV CX, 10
print_abs_days:
    MOV AL, [SI]
    CMP AL, 0
    JE skip_day_print
    CALL print_number
    PUSH DX
    MOV DL, ' '
    MOV AH, 02h
    INT 21h
    POP DX
skip_day_print:
    INC SI
    LOOP print_abs_days
    POP BX
    
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    ; Viva Marks
    LEA DX, viva_marks_lbl
    MOV AH, 09h
    INT 21h
    MOV SI, current_viva
    MOV AL, [SI+BX]
    CALL print_number
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    ; Attendance Marks
    LEA DX, attend_marks_lbl
    MOV AH, 09h
    INT 21h
    MOV SI, current_att_mrks
    MOV AL, [SI+BX]
    CALL print_number
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    ; Grade
    LEA DX, grade_lbl
    MOV AH, 09h
    INT 21h
    MOV SI, current_grades
    MOV AL, [SI+BX]
    CMP AL, 1
    JE show_colleg
    CMP AL, 2
    JE show_non_colleg
    CMP AL, 3
    JE show_dis_colleg
    LEA DX, newline
    JMP show_grade_done
show_colleg:
    LEA DX, collegiate_str
    JMP show_grade_done
show_non_colleg:
    LEA DX, non_colleg_str
    JMP show_grade_done
show_dis_colleg:
    LEA DX, dis_colleg_str
show_grade_done:
    MOV AH, 09h
    INT 21h
    RET

search_not_found_lbl:
    LEA DX, search_not_found
    MOV AH, 09h
    INT 21h
    RET
search_student ENDP

; ==================== BUBBLE SORT (Feature 4) ====================
bubble_sort_ids PROC
    ; Copy IDs to sorted array with indices
    MOV SI, current_ids
    LEA DI, sorted_ids
    MOV CX, MAX_STUDENTS
    MOV BX, 0
copy_loop:
    MOV AL, [SI+BX]
    MOV [DI+BX], AL
    MOV sorted_indices[BX], BL
    INC BX
    LOOP copy_loop
    
    ; Bubble sort
    MOV CX, MAX_STUDENTS
    DEC CX
outer_loop:
    PUSH CX
    LEA SI, sorted_ids
    LEA DI, sorted_indices
    MOV BX, 0
    
inner_loop:
    MOV AL, [SI+BX]
    MOV AH, [SI+BX+1]
    CMP AL, AH
    JLE no_swap
    
    ; Swap IDs
    MOV [SI+BX], AH
    MOV [SI+BX+1], AL
    
    ; Swap indices
    MOV AL, [DI+BX]
    MOV AH, [DI+BX+1]
    MOV [DI+BX], AH
    MOV [DI+BX+1], AL
    
no_swap:
    INC BX
    LOOP inner_loop
    
    POP CX
    LOOP outer_loop
    RET
bubble_sort_ids ENDP

; ==================== BINARY SEARCH (Feature 4) ====================
binary_search PROC
    ; Input: temp_id, Output: BX = original index or 0xFFFF
    MOV SI, 0           ; Left
    MOV DI, MAX_STUDENTS
    DEC DI              ; Right
    
bin_search_loop:
    CMP SI, DI
    JG not_found_bin
    
    ; Mid = (left + right) / 2
    MOV AX, SI
    ADD AX, DI
    SHR AX, 1
    MOV BX, AX
    
    LEA CX, sorted_ids
    ADD CX, BX
    PUSH SI
    MOV SI, CX
    MOV AL, [SI]
    POP SI
    
    CMP AL, temp_id
    JE found_bin
    JL search_right
    
    ; Search left
    MOV DI, BX
    DEC DI
    JMP bin_search_loop

search_right:
    MOV SI, BX
    INC SI
    JMP bin_search_loop

found_bin:
    ; Get original index
    MOV AL, sorted_indices[BX]
    XOR AH, AH
    MOV BX, AX
    RET

not_found_bin:
    MOV BX, 0FFFFh
    RET
binary_search ENDP

; ==================== RANDOM VIVA SELECTION (Feature 5) ====================
random_viva_select PROC
    LEA DX, viva_select_msg
    MOV AH, 09h
    INT 21h
    
viva_loop:
    ; Build active pool of present students WITHOUT viva marks
    MOV active_count, 0
    MOV CX, MAX_STUDENTS
    MOV BX, 0
    LEA DI, active_pool
    MOV SI, current_status
    
build_pool:
    ; Check if student is present (status != 0)
    MOV AL, [SI+BX]
    CMP AL, 0           ; Absent
    JE skip_pool
    
    ; Check if viva mark is not given yet (viva mark == 0)
    PUSH SI
    MOV SI, current_viva
    MOV AL, [SI+BX]
    CMP AL, 0           ; Viva mark not given
    POP SI
    JNE skip_pool       ; Skip if viva mark already given
    
    ; Add to pool (student is present AND viva mark not given)
    PUSH SI
    MOV SI, current_ids
    MOV AL, [SI+BX]
    POP SI
    
    PUSH BX
    XOR BH, BH
    MOV BL, active_count
    MOV [DI+BX], AL
    POP BX
    
    INC active_count

skip_pool:
    INC BX
    LOOP build_pool
    
    ; Check if any students available for viva
    CMP active_count, 0
    JE no_available_students
    
    ; Get random using timer
    MOV AH, 00h
    INT 1Ah
    
    ; Modulus operation
    XOR AH, AH
    MOV AL, DL          ; Low byte of timer
    XOR DX, DX
    XOR CH, CH
    MOV CL, active_count
    DIV CX              ; DX = remainder = random index
    
    ; Get selected student
    LEA SI, active_pool
    ADD SI, DX
    MOV AL, [SI]
    MOV temp_id, AL
    
    LEA DX, viva_selected
    MOV AH, 09h
    INT 21h
    
    MOV AL, temp_id
    CALL print_number
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    ; Prompt for viva mark
    CALL input_viva_mark
    
    ; Ask if teacher wants to select another student
    LEA DX, viva_another
    MOV AH, 09h
    INT 21h
    
    ; Read character
    MOV AH, 01h
    INT 21h
    
    ; If 'Y' or 'y', continue loop to select another student
    CMP AL, 'Y'
    JE viva_loop
    CMP AL, 'y'
    JE viva_loop
    
    ; Any other key (including 'N', 'n', or anything else), return to menu
    RET

no_available_students:
    ; Check if we're in the loop (after at least one viva mark entered)
    ; If active_count is 0 in the loop, all students have viva marks
    LEA DX, viva_all_done
    MOV AH, 09h
    INT 21h
    RET

no_present_students:
    LEA DX, viva_no_present
    MOV AH, 09h
    INT 21h
    RET
random_viva_select ENDP

; ==================== INPUT VIVA MARK ====================
input_viva_mark PROC
    LEA DX, viva_mark_prompt
    MOV AH, 09h
    INT 21h
    
    CALL read_two_digit_number
    
    ; Clamp to 0-10
    CMP AL, 10
    JLE mark_ok
    MOV AL, 10
mark_ok:
    PUSH AX
    
    ; Find student and store mark
    CALL find_student_index
    CMP BX, 0FFFFh
    JE viva_invalid
    
    POP AX
    MOV SI, current_viva
    MOV [SI+BX], AL
    
    LEA DX, viva_saved
    MOV AH, 09h
    INT 21h
    RET

viva_invalid:
    POP AX
    RET
input_viva_mark ENDP

; ==================== ENTER VIVA MARKS (Feature 7) ====================
enter_viva_marks PROC
enter_viva_loop:
    LEA DX, manual_viva_id
    MOV AH, 09h
    INT 21h
    
    CALL read_number
    MOV temp_id, AL
    
    ; Validate student ID
    CALL find_student_index
    CMP BX, 0FFFFh
    JE invalid_viva_id
    
    ; Valid ID, proceed to enter mark
    CALL input_viva_mark
    RET

invalid_viva_id:
    LEA DX, viva_invalid_id
    MOV AH, 09h
    INT 21h
    JMP enter_viva_loop
enter_viva_marks ENDP

; ==================== VIEW ALL STUDENTS ====================
view_all_students PROC
    ; Calculate grades if not already calculated
    CALL calculate_all_grades
    
    LEA DX, view_header
    MOV AH, 09h
    INT 21h
    
    MOV CX, MAX_STUDENTS
    MOV BX, 0
    
view_loop:
    PUSH CX
    PUSH BX
    
    ; ID
    MOV SI, current_ids
    MOV AL, [SI+BX]
    CALL print_number
    
    LEA DX, pipe_str
    MOV AH, 09h
    INT 21h
    
    ; Status
    MOV SI, current_status
    MOV AL, [SI+BX]
    CMP AL, 0
    JE view_absent
    CMP AL, 1
    JE view_present
    ; Late
    MOV DL, 'L'
    MOV AH, 02h
    INT 21h
    JMP view_after_status
view_absent:
    MOV DL, 'A'
    MOV AH, 02h
    INT 21h
    JMP view_after_status
view_present:
    MOV DL, 'P'
    MOV AH, 02h
    INT 21h
view_after_status:
    LEA DX, space_str
    MOV AH, 09h
    INT 21h
    LEA DX, pipe_str
    MOV AH, 09h
    INT 21h
    
    ; Present count
    MOV SI, current_present
    MOV AL, [SI+BX]
    CALL print_number
    
    LEA DX, space_str
    MOV AH, 09h
    INT 21h
    LEA DX, pipe_str
    MOV AH, 09h
    INT 21h
    
    ; Absent count
    MOV SI, current_absent
    MOV AL, [SI+BX]
    CALL print_number
    
    LEA DX, space_str
    MOV AH, 09h
    INT 21h
    LEA DX, pipe_str
    MOV AH, 09h
    INT 21h
    
    ; Grade
    MOV SI, current_grades
    MOV AL, [SI+BX]
    CMP AL, 1
    JE view_g_c
    CMP AL, 2
    JE view_g_nc
    CMP AL, 3
    JE view_g_dc
    MOV DL, '-'
    JMP view_print_grade
view_g_c:
    MOV DL, 'C'
    JMP view_print_grade
view_g_nc:
    MOV DL, 'N'
    JMP view_print_grade
view_g_dc:
    MOV DL, 'D'
view_print_grade:
    MOV AH, 02h
    INT 21h
    
    LEA DX, space_str
    MOV AH, 09h
    INT 21h
    LEA DX, pipe_str
    MOV AH, 09h
    INT 21h
    
    ; Calculate and display Attendance Marks based on grade
    MOV SI, current_grades
    MOV AL, [SI+BX]
    CMP AL, 3          ; Discollegiate
    JE att_mark_0
    CMP AL, 1          ; Collegiate
    JE att_mark_5
    ; Middle (Non-Collegiate)
    MOV AL, 4
    JMP att_mark_done
att_mark_0:
    MOV AL, 0
    JMP att_mark_done
att_mark_5:
    MOV AL, 5
att_mark_done:
    PUSH AX            ; Save attendance mark for total calculation
    CALL print_number
    
    LEA DX, space_str
    MOV AH, 09h
    INT 21h
    LEA DX, pipe_str
    MOV AH, 09h
    INT 21h
    
    ; Display Viva Marks
    MOV SI, current_viva
    MOV AL, [SI+BX]
    PUSH AX            ; Save viva mark for total calculation
    CALL print_number
    
    LEA DX, space_str
    MOV AH, 09h
    INT 21h
    LEA DX, pipe_str
    MOV AH, 09h
    INT 21h
    
    ; Calculate and display Total (Attendance + Viva)
    POP DX             ; Get viva mark (last pushed)
    XOR DH, DH         ; Clear upper byte
    POP AX             ; Get attendance mark (first pushed)
    XOR AH, AH         ; Clear upper byte
    ADD AL, DL         ; Add viva to attendance
    CALL print_number
    
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    
    POP BX
    POP CX
    INC BX
    DEC CX
    JNZ view_loop
    
    RET
view_all_students ENDP

; ==================== ADVANCE DAY ====================
advance_day PROC
    INC current_day
    INC total_classes
    
    ; Reset daily status
    MOV SI, current_status
    MOV CX, MAX_STUDENTS
    MOV BX, 0
reset_loop:
    MOV BYTE PTR [SI+BX], 0
    INC BX
    LOOP reset_loop
    
    LEA DX, day_msg
    MOV AH, 09h
    INT 21h
    
    MOV AL, current_day
    CALL print_number
    
    LEA DX, next_day_msg
    MOV AH, 09h
    INT 21h
    RET
advance_day ENDP

; ==================== PRINT NUMBER ====================
print_number PROC
    ; AL = number to print (0-255)
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    
    XOR AH, AH
    MOV BX, 10
    MOV CX, 0
    
divide_loop:
    XOR DX, DX
    DIV BX
    PUSH DX
    INC CX
    CMP AX, 0
    JNE divide_loop
    
print_digit_loop:
    POP DX
    ADD DL, '0'
    MOV AH, 02h
    INT 21h
    LOOP print_digit_loop
    
    POP DX
    POP CX
    POP BX
    POP AX
    RET
print_number ENDP

END MAIN
