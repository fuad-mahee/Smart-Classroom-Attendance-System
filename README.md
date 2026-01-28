# Smart Classroom Attendance System

## Overview
The Smart Classroom Attendance System is an x86 Assembly project designed to automate and secure the process of classroom attendance, eligibility calculation, and viva management. It features robust authentication, real-time latency detection, undo/redo correction, and fair viva candidate selection, all implemented at the hardware level for reliability and transparency.

## Features

### 1. Smart Roll Call with Latency Detection
- Validates student IDs against the class roster.
- Uses the system timer (INT 1Ah) to detect late entries.
- Marks students as Present, Late, or Absent based on timing.
- Pushes each attendance action onto an undo stack for correction.

### 2. Advanced Correction Log (Undo/Redo with Security Buffer)
- Allows undo/redo of attendance actions with a secure buffer time.
- Requires re-authentication for corrections after the buffer expires.
- Maintains a stack-based log of all changes for auditability.

### 3. Eligibility, Marks Calculation & Viva Integration
- Calculates attendance percentage and assigns grades (Collegiate, Non-Collegiate, Dis-Collegiate).
- Integrates viva marks with attendance for comprehensive assessment.
- Stores and displays all academic marks for each student.

### 4. Deep Student Status Search (Optimized)
- Implements bubble sort and binary search for fast student lookup.
- Displays daily status, total presents/absents, absent days, and marks.

### 5. Randomized Viva Candidate Selector
- Builds an active pool of present students.
- Uses the system timer and modulus operation for fair random selection.
- Prompts for viva mark entry and stores it securely.

### 6. Secure Session Lock & Data Partitioning
- Requires password authentication for teachers.
- Partitions data for Section A and Section B to ensure privacy and integrity.
- Prevents cross-section data access and modification.

## Usage
1. **Build and run the program in an x86 emulator (e.g., EMU8086, DOSBox).**
2. **Login as Teacher A or Teacher B using the provided credentials:**
   - Teacher A: `admin1`
   - Teacher B: `admin2`
3. **Follow the on-screen menu to perform roll call, corrections, search, viva selection, and more.**
4. **All actions are logged and can be undone/redone within security constraints.**

## Data Structures
- **Arrays:** Used for student IDs, status, attendance, grades, viva marks, and absent days.
- **Stacks:** Used for undo/redo logs with timestamping for security.
- **Active Pool:** Temporary array for random viva selection.

## System Requirements
- x86 Assembly compatible emulator (EMU8086, DOSBox, or similar)
- DOS environment or emulator

## File Structure
- `projectcode.asm` — Main source code for the attendance system


## Authors
- Muftasim Fuad Mahee
- Nabil Thahamid Chowdhury
- Mohammed Ahnaf

## License
This project is for educational purposes. Please credit the authors if reusing or modifying the code.
