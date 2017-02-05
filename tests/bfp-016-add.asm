  TITLE 'bfp-016-add.asm: Test IEEE Add'
***********************************************************************
*
*Testcase IEEE ADD
*  Test case capability includes IEEE exceptions trappable and 
*  otherwise. Test results, FPCR flags, the Condition code, and any
*  DXC are saved for all tests.
*
***********************************************************************
         SPACE 2
***********************************************************************
*
*                         bfp-016-add.asm 
*
*        This assembly-language source file is part of the
*        Hercules Binary Floating Point Validation Package 
*                        by Stephen R. Orso
*
* Copyright 2016 by Stephen R Orso.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
*
* 1. Redistributions of source code must retain the above copyright
*    notice, this list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright
*    notice, this list of conditions and the following disclaimer in
*    the documentation and/or other materials provided  with the
*    distribution.
*
* 3. The name of the author may not be used to endorse or promote
*    products derived from this software without specific prior written
*    permission.
*
* DISCLAMER: THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
* THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
* PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
* HOLDER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
***********************************************************************
         SPACE 2
***********************************************************************
*
* Tests the following three conversion instructions
*   ADD (short BFP, RRE)
*   ADD (long BFP, RRE) 
*   ADD (extended BFP, RRE) 
*   ADD (short BFP, RXE)
*   ADD (long BFP, RXE) 
* 
* Test data is compiled into this program.  The test script that runs
* this program can provide alternative test data through Hercules R 
* commands.
* 
* Test Case Order
* 1) Short BFP basic tests, including traps and NaN propagation
* 2) Short BFP finite number tests, incl. traps and scaling
* 3) Short BFP FPC-controlled rounding mode exhaustive tests
* 4) Long BFP basic tests, including traps and NaN propagation
* 5) Long BFP finite number tests, incl. traps and scaling
* 6) Long BFP FPC-controlled rounding mode exhaustive tests
* 7) Extended BFP basic tests, including traps and NaN propagation
* 8) Extended BFP finite number tests, incl. traps and scaling
* 9) Extended BFP FPC-controlled rounding mode exhaustive tests
*
* Three input test sets are provided each for short, long, and 
*   extended BFP inputs.  Test values are the same for each precision
*   for most tests.  Overflow and underflow each require precision-
*   dependent test values.  
*
* Also tests the following floating point support instructions
*   LOAD  (Short)
*   LOAD  (Long)
*   LFPC  (Load Floating Point Control Register)
*   SRNMB (Set BFP Rounding Mode 3-bit)
*   STORE (Short)
*   STORE (Long)
*   STFPC (Store Floating Point Control Register)
*
***********************************************************************
         SPACE 2
         MACRO
         PADCSECT &ENDLABL
.*
.*  Macro to pad the CSECT to include result data areas if this test
.*  program is not being assembled using asma.  asma generates a core
.*  image that is loaded by the loadcore command, and because the 
.*  core image is a binary stored in Github, it makes sense to make
.*  this small effort to keep the core image small.  
.*
         AIF   (D'&ENDLABL).GOODPAD
         MNOTE 4,'Missing or invalid CSECT padding label ''&ENDLABL'''
         MNOTE *,'No CSECT padding performed'  
         MEXIT
.*
.GOODPAD ANOP            Label valid.  See if we're on asma
         AIF   ('&SYSASM' EQ 'A SMALL MAINFRAME ASSEMBLER').NOPAD
         ORG   &ENDLABL-1   Not ASMA.  Pad CSECT
         MEXIT
.*
.NOPAD   ANOP
         MNOTE *,'asma detected; no CSECT padding performed'  
         MEND
*
*  Note: for compatibility with the z/CMS test rig, do not change
*  or use R11, R14, or R15.  Everything else is fair game.  
*
BFPADD   START 0
STRTLABL EQU   *
R0       EQU   0                   Work register for cc extraction
R1       EQU   1
R2       EQU   2                   Holds count of test input values
R3       EQU   3                   Points to next test input value(s)
R4       EQU   4                   Rounding tests inner loop control
R5       EQU   5                   Rounding tests outer loop control
R6       EQU   6                   Rounding tests top of inner loop
R7       EQU   7                   Pointer to next result value(s)
R8       EQU   8                   Pointer to next FPCR result
R9       EQU   9                   Rounding tests top of outer loop
R10      EQU   10                  Pointer to test address list
R11      EQU   11                  **Reserved for z/CMS test rig
R12      EQU   12                  Holds number of test cases in set
R13      EQU   13                  Mainline return address
R14      EQU   14                  **Return address for z/CMS test rig
R15      EQU   15                  **Base register on z/CMS or Hyperion
*
* Floating Point Register equates to keep the cross reference clean
*
FPR0     EQU   0
FPR1     EQU   1
FPR2     EQU   2
FPR3     EQU   3
FPR4     EQU   4
FPR5     EQU   5
FPR6     EQU   6
FPR7     EQU   7
FPR8     EQU   8
FPR9     EQU   9
FPR10    EQU   10
FPR11    EQU   11
FPR12    EQU   12
FPR13    EQU   13
FPR14    EQU   14
FPR15    EQU   15
*
         USING *,R15
*
* Above works on real iron (R15=0 after sysclear) 
* and in z/CMS (R15 points to start of load module)
*
         SPACE 2 
***********************************************************************
*
* Low core definitions, Restart PSW, and Program Check Routine.
*
***********************************************************************
         SPACE 2
         ORG   STRTLABL+X'8E'      Program check interrution code
PCINTCD  DS    H
*
PCOLDPSW EQU   STRTLABL+X'150'     z/Arch Program check old PSW
*
         ORG   STRTLABL+X'1A0'     z/Arch Restart PSW
         DC    X'0000000180000000',AD(START)   
*
         ORG   STRTLABL+X'1D0'     z/Arch Program check old PSW
         DC    X'0000000000000000',AD(PROGCHK)
* 
* Program check routine.  If Data Exception, continue execution at
* the instruction following the program check.  Otherwise, hard wait.
* No need to collect data.  All interesting DXC stuff is captured
* in the FPCR.
*
         ORG   STRTLABL+X'200'
PROGCHK  DS    0H             Program check occured...
         CLI   PCINTCD+1,X'07'  Data Exception?
         JNE   PCNOTDTA       ..no, hardwait (not sure if R15 is ok)
         LPSWE PCOLDPSW       ..yes, resume program execution
PCNOTDTA DS    0H
         LTR   R14,R14        Return address provided?
         BNZR  R14            Yes, return to z/CMS test rig.  
         LPSWE HARDWAIT       Not data exception, enter disabled wait
         EJECT
***********************************************************************
*
*  Main program.  Enable Advanced Floating Point, process test cases.
*
***********************************************************************
         SPACE 2
START    DS    0H
         STCTL R0,R0,CTLR0    Store CR0 to enable AFP
         OI    CTLR0+1,X'04'  Turn on AFP bit
         LCTL  R0,R0,CTLR0    Reload updated CR0
*
         LA    R10,SHORTNF   Point to short BFP non-finite inputs
         BAS   R13,SBFPNF    Add short BFP non-finites
         LA    R10,SHORTF    Point to short BFP finite inputs
         BAS   R13,SBFPF     Add short BFP finites
         LA    R10,RMSHORTS  Point to short BFP rounding mode tests
         BAS   R13,SBFPRM    Add short BFP for rounding tests
*
         LA    R10,LONGNF    Point to long BFP non-finite inputs
         BAS   R13,LBFPNF    Add long BFP non-finites
         LA    R10,LONGF     Point to long BFP finite inputs
         BAS   R13,LBFPF     Add long BFP finites
         LA    R10,RMLONGS   Point to long  BFP rounding mode tests
         BAS   R13,LBFPRM    Add long BFP for rounding tests
*
         LA    R10,XTNDNF    Point to extended BFP non-finite inputs
         BAS   R13,XBFPNF    Add extended BFP non-finites
         LA    R10,XTNDF     Point to ext'd BFP finite inputs
         BAS   R13,XBFPF     Add ext'd BFP finites
         LA    R10,RMXTNDS   Point to ext'd BFP rounding mode tests
         BAS   R13,XBFPRM    Add ext'd BFP for rounding tests
*
         LTR   R14,R14       Return address provided?
         BNZR  R14           ..Yes, return to z/CMS test rig.  
         LPSWE WAITPSW       All done
*
         DS    0D            Ensure correct alignment for psw
WAITPSW  DC    X'0002000000000000',AD(0)  Normal end - disabled wait
HARDWAIT DC    X'0002000000000000',XL6'00',X'DEAD' Abnormal end
*
CTLR0    DS    F
FPCREGNT DC    X'00000000'  FPCR, trap all IEEE exceptions, zero flags
FPCREGTR DC    X'F8000000'  FPCR, trap no IEEE exceptions, zero flags
*
* Input values parameter list, four fullwords for each test data set 
*      1) Count, 
*      2) Address of inputs, 
*      3) Address to place results, and
*      4) Address to place DXC/Flags/cc values.  
*
         ORG   STRTLABL+X'300'  Enable run-time replacement
SHORTNF  DS    0F           Input pairs for short BFP non-finite tests
         DC    A(SBFPNFCT)
         DC    A(SBFPNFIN)
         DC    A(SBFPNFOT)
         DC    A(SBFPNFFL)
*
SHORTF   DS    0F           Input pairs for short BFP finite tests
         DC    A(SBFPCT)
         DC    A(SBFPIN)
         DC    A(SBFPOUT)
         DC    A(SBFPFLGS)
*
RMSHORTS DS    0F           Input pairs for short BFP rounding testing
         DC    A(SBFPRMCT)
         DC    A(SBFPINRM)
         DC    A(SBFPRMO)
         DC    A(SBFPRMOF)
*
LONGNF   DS    0F           Input pairs for long BFP non-finite testing
         DC    A(LBFPNFCT)
         DC    A(LBFPNFIN)
         DC    A(LBFPNFOT)
         DC    A(LBFPNFFL)
*
LONGF    DS    0F           Input pairs for long BFP finite testing
         DC    A(LBFPCT)
         DC    A(LBFPIN)
         DC    A(LBFPOUT)
         DC    A(LBFPFLGS)
*
RMLONGS  DS    0F           Input pairs for long BFP rounding testing
         DC    A(LBFPRMCT)
         DC    A(LBFPINRM)
         DC    A(LBFPRMO)
         DC    A(LBFPRMOF)
*
XTNDNF   DS    0F           Inputs for ext'd BFP non-finite testing
         DC    A(XBFPNFCT)
         DC    A(XBFPNFIN)
         DC    A(XBFPNFOT)
         DC    A(XBFPNFFL)
*
XTNDF    DS    0F           Inputs for ext'd BFP finite testing
         DC    A(XBFPCT)
         DC    A(XBFPIN)
         DC    A(XBFPOUT)
         DC    A(XBFPFLGS)
*
RMXTNDS  DS    0F           Inputs for ext'd BFP non-finite testing
         DC    A(XBFPRMCT)
         DC    A(XBFPINRM)
         DC    A(XBFPRMO)
         DC    A(XBFPRMOF)
*
         EJECT
***********************************************************************
*
* Perform Add using provided short BFP inputs.  This set of tests
* checks NaN propagation, operations on values that are not finite
* numbers, and other basic tests.  This set generates results that can
* be validated against Figure 19-13 on page 19-16 of SA22-7832-10.  
*
* That Figure has separate rows and colums for Normal and Tiny
* operands.  Although the results are effectively the same for Normal
* and Tiny in any combination, the input data includes Normal and 
* Tiny values.  
*
* Four results are generated for each input: one RRE with all 
* exceptions non-trappable, a second RRE with all exceptions trappable,
* a third RXE with all exceptions non-trappable, a fourth RXE with all 
* exceptions trappable,
*
* The sum, FPCR, and condition code are stored for each result.  
*
***********************************************************************
         SPACE 2
SBFPNF   DS    0H            BFP Short non-finite values tests
         LM    R2,R3,0(R10)  Get count and address of add values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         BASR  R12,0         Set top of loop
*
         LM    R4,R5,0(R10)  Get count and start of addend values
*                            ..which are the same as the augends
         BASR  R6,0          Set top of inner loop
*
         LE    FPR8,0(,R3)   Get short BFP augend
         LE    FPR1,0(,R5)   Get short BFP addend
         LFPC  FPCREGNT      Set exceptions non-trappable
         AEBR  FPR8,FPR1     Add FPR0/FPR1 RRE
         STE   FPR8,0(,R7)   Store short BFP sum
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LE    FPR8,0(,R3)   Get short BFP augend
         LE    FPR1,0(,R5)   Get short BFP addend
         LFPC  FPCREGTR      Set exceptions trappable
         AEBR  FPR8,FPR1     Add FPR0/FPR1 RRE
         STE   FPR8,4(,R7)   Store short BFP sum
         STFPC 4(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,7(,R8)     Save condition code in results table
*
         LE    FPR8,0(,R3)   Get short BFP augend
         LE    FPR1,0(,R5)   Get short BFP addend
         LFPC  FPCREGNT      Set exceptions non-trappable
         AEB   FPR8,0(,R5)   Add FPR0/FPR1 RXE
         STE   FPR8,8(,R7)   Store short BFP sum
         STFPC 8(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,11(,R8)    Save condition code in results table
*
         LE    FPR8,0(,R3)   Get short BFP augend
         LFPC  FPCREGTR      Set exceptions trappable
         AEB   FPR8,0(,R5)   Add FPR0/FPR1 RXE
         STE   FPR8,12(,R7)  Store short BFP sum
         STFPC 12(R8)        Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,15(,R8)    Save condition code in results table
*
         LA    R5,4(,R5)     Point to next addend value
         LA    R7,4*4(,R7)   Point to next Add result area
         LA    R8,4*4(,R8)   Point to next Add FPCR area
         BCTR  R4,R6         Loop through right-hand values
*
         LA    R3,4(,R3)     Point to next input augend
         BCTR  R2,R12        Loop through left-hand values
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Perform Add using provided short BFP input pairs.  This set of 
* tests triggers IEEE exceptions Overflow, Underflow, and Inexact and 
* collects both trap and non-trap results.
*
* Four results are generated for each input: one RRE with all 
* exceptions non-trappable, a second RRE with all exceptions trappable,
* a third RXE with all exceptions non-trappable, a fourth RXE with all 
* exceptions trappable,
* 
* The sum, FPCR, and condition code are stored for each result.  
*
***********************************************************************
         SPACE 2
SBFPF    LM    R2,R3,0(R10)  Get count and address of test input values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         BASR  R12,0         Set top of loop
*
         LFPC  FPCREGNT      Set exceptions non-trappable
         LE    FPR8,0(,R3)   Get short BFP augend
         LE    FPR1,4(,R3)   Get short BFP addend
         AEBR  FPR8,FPR1     Add FPR8/FPR1 RRE non-trappable
         STE   FPR8,0(,R7)   Store short BFP sum
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LFPC  FPCREGTR      Set exceptions trappable
         LE    FPR8,0(,R3)   Reload short BFP augend
*                            ..addend is still in FPR1
         AEBR  FPR8,FPR1     Add FPR8/FPR1 RRE trappable
         STE   FPR8,4(,R7)   Store short BFP sum
         STFPC 4(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,7(,R8)     Save condition code in results table
*
         LFPC  FPCREGNT      Set exceptions non-trappable
         LE    FPR8,0(,R3)   Reload short BFP augend
         AEB   FPR8,4(,R3)   Add FPR8 by addend RXE non-trappable
         STE   FPR8,8(,R7)   Store short BFP sum
         STFPC 8(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,11(,R8)    Save condition code in results table
*
         LFPC  FPCREGTR      Set exceptions trappable
         LE    FPR8,0(,R3)   Reload short BFP augend
         AEB   FPR8,4(,R3)   Add FPR8 by addend RXE trappable
         STE   FPR8,12(,R7)  Store short BFP sum
         STFPC 12(R8)        Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,15(,R8)    Save condition code in results table
*
         LA    R3,2*4(,R3)   Point to next input value pair
         LA    R7,4*4(,R7)   Point to next sum result set
         LA    R8,4*4(,R8)   Point to next FPCR result set
         BCTR  R2,R12        Convert next input value.  
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Perform Add using provided short BFP input pairs.  This set of 
* tests exhaustively tests all rounding modes available for Add.
* The rounding mode can only be specified in the FPC.  
*
* All five FPC rounding modes are tested because the preceeding tests,
* using rounding mode RNTE, do not often create results that require
* rounding.  
*
* Two results are generated for each input and rounding mode: one RRE 
* and one RXE.  Traps are disabled for all rounding mode tests.  
*
* The sum, FPCR, and condition code are stored for each test.  
*
***********************************************************************
         SPACE 2
SBFPRM   LM    R2,R3,0(R10)  Get count and address of test input values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         XR    R1,R1         Zero register 1 for use in IC/STC/indexing
         BASR  R12,0         Set top of test case loop
         
         LA    R5,FPCMCT     Get count of FPC modes to be tested
         BASR  R9,0          Set top of rounding mode outer loop
*
         IC    R1,FPCMODES-L'FPCMODES(R5)  Get next FPC mode
*
         LFPC  FPCREGNT      Set exceptions non-trappable, clear flags
         SRNMB 0(R1)         Set FPC Rounding Mode
         LE    FPR8,0(,R3)   Get short BFP augend
         LE    FPR1,4(,R3)   Get short BFP addend
         AEBR  FPR8,FPR1     Add RRE FPR8/FPR1 non-trappable
         STE   FPR8,0(,R7)   Store short BFP sum
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LFPC  FPCREGNT      Set exceptions non-trappable, clear flags
         SRNMB 0(R1)         Set FPC Rounding Mode
         LE    FPR8,0(,R3)   Get short BFP augend
         AEB   FPR8,4(,R3)   Add RXE FPR8 by addend non-trappable
         STE   FPR8,4(,R7)   Store short BFP sum
         STFPC 4(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,7(,R8)     Save condition code in results table
*
         LA    R7,2*4(,R7)   Point to next sum result set
         LA    R8,2*4(,R8)   Point to next FPCR result area
*
         BCTR  R5,R9         Iterate to next FPC mode for this input
*
* End of FPC modes to be tested.  Advance to next test case.  We will
* skip eight bytes of result area so that each set of five result 
* value pairs starts at a memory address ending in zero for the 
* convenience of memory dump review.  
*         
         LA    R3,2*4(,R3)   Point to next input value pair
         LA    R7,8(,R7)     Skip to start of next result set
         LA    R8,8(,R8)     Skip to start of next FPCR result set
         BCTR  R2,R12        Advance to the next input pair
*
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Perform Add using provided long BFP inputs.  This set of tests
* checks NaN propagation, operations on values that are not finite
* numbers, and other basic tests.  This set generates results that can
* be validated against Figure 19-13 on page 19-16 of SA22-7832-10.  
*
* That Figure has separate rows and colums for Normal and Tiny
* operands.  Although the results are effectively the same for Normal
* and Tiny in any combination, the input data includes Normal and 
* Tiny values.  
*
* Four results are generated for each input: one RRE with all 
* exceptions non-trappable, a second RRE with all exceptions trappable,
* a third RXE with all exceptions non-trappable, a fourth RXE with all 
* exceptions trappable,
*
* The sum, FPCR, and condition code are stored for each result.  
*
***********************************************************************
         SPACE 2
LBFPNF   DS    0H            BFP long non-finite values tests
         LM    R2,R3,0(R10)  Get count and address of augend values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         BASR  R12,0         Set top of loop
*
         LM    R4,R5,0(R10)  Get count and start of addend values
*                            ..which are the same as the augends
         BASR  R6,0          Set top of inner loop
*
         LD    FPR8,0(,R3)   Get long BFP augend
         LD    FPR1,0(,R5)   Get long BFP addend
         LFPC  FPCREGNT      Set exceptions non-trappable
         ADBR  FPR8,FPR1     Add FPR0/FPR1 RRE
         STD   FPR8,0(,R7)   Store long BFP sum
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LD    FPR8,0(,R3)   Get long BFP augend
         LD    FPR1,0(,R5)   Get long BFP addend
         LFPC  FPCREGTR      Set exceptions trappable
         ADBR  FPR8,FPR1     Add FPR0/FPR1 RRE
         STD   FPR8,8(,R7)   Store long BFP remainder
         STFPC 4(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,7(,R8)     Save condition code in results table
*
         LD    FPR8,0(,R3)   Get long BFP augend
         LFPC  FPCREGNT      Set exceptions non-trappable
         ADB   FPR8,0(,R5)   Add FPR0/FPR1 RXE
         STD   FPR8,16(,R7)  Store long BFP sum
         STFPC 8(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,11(,R8)    Save condition code in results table
*
         LD    FPR8,0(,R3)   Get long BFP augend
         LFPC  FPCREGTR      Set exceptions trappable
         ADB   FPR8,0(,R5)   Add FPR0/FPR1 RXE
         STD   FPR8,24(,R7)  Store long BFP remainder
         STFPC 12(R8)        Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,15(,R8)    Save condition code in results table
*
         LA    R5,8(,R5)     Point to next addend value
         LA    R7,4*8(,R7)   Point to next Add result area
         LA    R8,4*4(,R8)   Point to next Add FPCR area
         BCTR  R4,R6         Loop through right-hand values
*
         LA    R3,8(,R3)     Point to next augend value
         BCTR  R2,R12        Add until all cases tested
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Perform Add using provided long BFP input pairs.  This set of
* tests triggers IEEE exceptions Overflow, Underflow, and Inexact and
* collects non-trap and trap results.
*
* Four results are generated for each input: one RRE with all 
* exceptions non-trappable, a second RRE with all exceptions trappable,
* a third RXE with all exceptions non-trappable, a fourth RXE with all 
* exceptions trappable,
* 
* The sum, FPCR, and condition code are stored for each result.  
*
***********************************************************************
         SPACE 2
LBFPF    LM    R2,R3,0(R10)  Get count and address of test input values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         BASR  R12,0         Set top of loop
*
         LFPC  FPCREGNT      Set exceptions non-trappable
         LD    FPR8,0(,R3)   Get short BFP augend
         LD    FPR1,8(,R3)   Get short BFP addend
         ADBR  FPR8,FPR1     Add FPR8/FPR1 RRE non-trappable
         STD   FPR8,0(,R7)   Store short BFP sum
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LFPC  FPCREGTR      Set exceptions trappable
         LD    FPR8,0(,R3)   Reload short BFP augend
*                            ..addend is still in FPR1
         ADBR  FPR8,FPR1     Add FPR8/FPR1 RRE trappable
         STD   FPR8,8(,R7)   Store short BFP sum
         STFPC 4(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,7(,R8)     Save condition code in results table
*
         LFPC  FPCREGNT      Set exceptions non-trappable
         LD    FPR8,0(,R3)   Reload short BFP augend
         ADB   FPR8,8(,R3)   Add FPR8/FPR1 RXE non-trappable
         STD   FPR8,16(,R7)  Store short BFP sum
         STFPC 8(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,11(,R8)    Save condition code in results table
*
         LFPC  FPCREGTR      Set exceptions trappable
         LD    FPR8,0(,R3)   Reload short BFP augend
         ADB   FPR8,8(,R3)   Add FPR8/FPR1 RXE trappable
         STD   FPR8,24(,R7)  Store short BFP sum
         STFPC 12(R8)        Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,15(,R8)    Save condition code in results table
*
         LA    R3,2*8(,R3)   Point to next input value pair
         LA    R7,4*8(,R7)   Point to next quotent result pair
         LA    R8,4*4(,R8)   Point to next FPCR result area
         BCTR  R2,R12        Convert next input value.  
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Perform Add using provided long BFP input pairs.  This set of 
* tests exhaustively tests all rounding modes available for Add.
* The rounding mode can only be specified in the FPC.  
*
* All five FPC rounding modes are tested because the preceeding tests,
* using rounding mode RNTE, do not often create results that require
* rounding.  
*
* Two results are generated for each input and rounding mode: one RRE 
* and one RXE.  Traps are disabled for all rounding mode tests.  
*
* The sum, FPCR, and condition code are stored for each result.  
*
***********************************************************************
         SPACE 2
LBFPRM   LM    R2,R3,0(R10)  Get count and address of test input values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         XR    R1,R1         Zero register 1 for use in IC/STC/indexing
         BASR  R12,0         Set top of test case loop
         
         LA    R5,FPCMCT     Get count of FPC modes to be tested
         BASR  R9,0          Set top of rounding mode loop
*
         IC    R1,FPCMODES-L'FPCMODES(R5)  Get next FPC mode
*
         LFPC  FPCREGNT      Set exceptions non-trappable, clear flags
         SRNMB 0(R1)         Set FPC Rounding Mode
         LD    FPR8,0(,R3)   Get long BFP augend
         LD    FPR1,8(,R3)   Get long BFP addend
         ADBR  FPR8,FPR1     Add RRE FPR8/FPR1 non-trappable
         STD   FPR8,0(,R7)   Store long BFP sum
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LFPC  FPCREGNT      Set exceptions non-trappable, clear flags
         SRNMB 0(R1)         Set FPC Rounding Mode
         LD    FPR8,0(,R3)   Reload long BFP augend
         ADB   FPR8,8(,R3)   Add RXE FPR8 by addend non-trappable
         STD   FPR8,8(,R7)   Store long BFP sum
         STFPC 4(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,7(,R8)     Save condition code in results table
*
         LA    R7,2*8(,R7)   Point to next sum result set
         LA    R8,2*4(,R8)   Point to next FPCR result area
*
         BCTR  R5,R9         Iterate to next FPC mode
*
* End of FPC modes to be tested.  Advance to next test case.  We will
* skip eight bytes of FPCR result area so that each set of five result 
* FPCR contents pairs starts at a memory address ending in zero for the 
* convenience of memory dump review.  
*         
         LA    R3,2*8(,R3)   Point to next input value pair
         LA    R8,8(,R8)     Skip to start of next FPCR result area
         BCTR  R2,R12        Add next input value lots of times
*
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Perform Add using provided extended BFP inputs.  This set of tests
* checks NaN propagation, operations on values that are not finite
* numbers, and other basic tests.  This set generates results that can
* be validated against Figure 19-13 on page 19-16 of SA22-7832-10.  
*
* That Figure has separate rows and colums for Normal and Tiny
* operands.  Although the results are effectively the same for Normal
* and Tiny in any combination, the input data includes Normal and 
* Tiny values.  
*
* Two results are generated for each input: one RRE with all 
* exceptions non-trappable, and a second RRE with all exceptions 
* trappable.  Extended BFP Add does not have an RXE format.
*
* The sum, FPCR, and condition code are stored for each result.  
*
***********************************************************************
         SPACE 2
XBFPNF   DS    0H            BFP extended non-finite values tests
         LM    R2,R3,0(R10)  Get count and address of augend values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         BASR  R12,0         Set top of loop
*
         LM    R4,R5,0(R10)  Get count and start of addend values
*                            ..which are the same as the augends
         BASR  R6,0          Set top of inner loop
*
         LD    FPR8,0(,R3)   Get extended BFP augend part 1
         LD    FPR10,8(,R3)  Get extended BFP augend part 2
         LD    FPR1,0(,R5)   Get extended BFP addend part 1
         LD    FPR3,8(,R5)   Get extended BFP addend part 2
         LFPC  FPCREGNT      Set exceptions non-trappable
         AXBR  FPR8,FPR1     Add FPR0/FPR1 RRE
         STD   FPR8,0(,R7)   Store extended BFP sum part 1
         STD   FPR10,8(,R7)  Store extended BFP sum part 2
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LD    FPR8,0(,R3)   Get extended BFP augend part 1
         LD    FPR10,8(,R3)  Get extended BFP augend part 2
         LD    FPR1,0(,R5)   Get extended BFP addend part 1
         LD    FPR3,8(,R5)   Get extended BFP addend part 2
         LFPC  FPCREGTR      Set exceptions trappable
         AXBR  FPR8,FPR1     Add FPR0/FPR1 RRE
         STD   FPR8,16(,R7)  Store extended BFP sum part 1
         STD   FPR10,24(,R7) Store extended BFP sum part 2
         STFPC 4(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,7(,R8)     Save condition code in results table
*
         LA    R5,16(,R5)    Point to next addend value
         LA    R7,32(,R7)    Point to next Add result area
         LA    R8,16(,R8)    Point to next Add FPCR area
         BCTR  R4,R6         Loop through right-hand values
*
         LA    R3,16(,R3)    Point to next augend value
         BCTR  R2,R12        Add until all cases tested
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Perform Add using provided extended BFP input pairs.  This set of
* tests triggers IEEE exceptions Overflow, Underflow, and Inexact and
* collects results when the exceptions do not result in a trap and when
* they do. 
*
* Two results are generated for each input: one RRE with all 
* exceptions non-trappable and a second RRE with all exceptions
* trappable.  There is no RXE format for Add in extended precision.
* 
* The sum, FPCR, and condition code are stored for each result.  
*
***********************************************************************
         SPACE 2
XBFPF    LM    R2,R3,0(R10)  Get count and address of test input values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         BASR  R12,0         Set top of loop
*
         LFPC  FPCREGNT      Set exceptions non-trappable
         LD    FPR8,0(,R3)   Get extended BFP augend part 1
         LD    FPR10,8(,R3)  Get extended BFP augend part 2
         LD    FPR1,16(,R3)  Get extended BFP addend part 1
         LD    FPR3,24(,R3)  Get extended BFP addend part 2
         AXBR  FPR8,FPR1     Add FPR8-10/FPR1-3 RRE non-trappable
         STD   FPR8,0(,R7)   Store extended BFP sum part 1
         STD   FPR10,8(,R7)  Store extended BFP sum part 2
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LFPC  FPCREGTR      Set exceptions trappable
         LD    FPR8,0(,R3)   Reload extended BFP augend part 1
         LD    FPR10,8(,R3)  Reload extended BFP augend part 2
*                            ..addend is still in FPR1-FPR3
         AXBR  FPR8,FPR1     Add FPR8-10/FPR1-3 RRE trappable
         STD   FPR8,16(,R7)  Store extended BFP sum part 1
         STD   FPR10,24(,R7) Store extended BFP sum part 2
         STFPC 4(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,7(,R8)     Save condition code in results table
*
         LA    R3,32(,R3)    Point to next input value pair
         LA    R7,32(,R7)    Point to next quotent result pair
         LA    R8,16(,R8)    Point to next FPCR result area
         BCTR  R2,R12        Convert next input value.  
*
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Perform Add using provided extended BFP input pairs.  This set of 
* tests exhaustively tests all rounding modes available for Add.
* The rounding mode can only be specified in the FPC.  
*
* All five FPC rounding modes are tested because the preceeding tests,
* using rounding mode RNTE, do not often create results that require
* rounding.  
*
* Two results are generated for each input and rounding mode: one RRE 
* and one RXE.  Traps are disabled for all rounding mode tests.  
*
* The sum, FPCR, and condition code are stored for each result.  
*
***********************************************************************
         SPACE 2
XBFPRM   LM    R2,R3,0(R10)  Get count and address of test input values
         LM    R7,R8,8(R10)  Get address of result area and flag area.
         LTR   R2,R2         Any test cases?
         BZR   R13           ..No, return to caller
         XR    R1,R1         Zero register 1 for use in IC/STC/indexing
         BASR  R12,0         Set top of test case loop
         
         LA    R5,FPCMCT     Get count of FPC modes to be tested
         BASR  R9,0          Set top of rounding mode loop
*
         IC    R1,FPCMODES-L'FPCMODES(R5)  Get next FPC mode
*
         LFPC  FPCREGNT      Set exceptions non-trappable, clear flags
         SRNMB 0(R1)         Set FPC Rounding Mode
         LD    FPR8,0(,R3)   Get extended BFP augend part 1
         LD    FPR10,8(,R3)  Get extended BFP augend part 2
         LD    FPR1,16(,R3)  Get extended BFP addend part 1
         LD    FPR3,24(,R3)  Get extended BFP addend part 2
         AXBR  FPR8,FPR1     Add RRE FPR8/FPR1 non-trappable
         STD   FPR8,0(,R7)   Store extended BFP sum part 1
         STD   FPR10,8(,R7)  Store extended BFP sum part 2
         STFPC 0(R8)         Store resulting FPCR flags and DXC
         IPM   R0            Get condition code and program mask
         SRL   R0,28         Isolate CC in low order byte
         STC   R0,3(,R8)     Save condition code in results table
*
         LA    R7,16(,R7)    Point to next sum result set
         LA    R8,4(,R8)     Point to next FPCR result area
*
         BCTR  R5,R9         Iterate to next FPC mode
*
* End of FPC modes to be tested.  Advance to next test case.  We will
* skip eight bytes of FPCR result area so that each set of five result 
* FPCR contents pairs starts at a memory address ending in zero for the 
* convenience of memory dump review.  
*         
         LA    R3,2*16(,R3)  Point to next input value pair
         LA    R8,12(,R8)    Skip to start of next FPCR result area
         BCTR  R2,R12        Add next input value lots of times
*
         BR    R13           All converted; return.
         EJECT
***********************************************************************
*
* Table of FPC rounding modes to test sum rounding modes.  
*
* The Set BFP Rounding Mode does allow specification of the FPC
* rounding mode as an address, so we shall index into a table of 
* BFP rounding modes without bothering with Execute. 
*
***********************************************************************
         SPACE 2
*
* Rounding modes that may be set in the FPCR.  The FPCR controls
* rounding of the sum.  
*
* These are indexed directly by the loop counter, which counts down.
* So the modes are listed in reverse order here.  
*
FPCMODES DS    0C
         DC    AL1(7)              RFS, Round for shorter precision
         DC    AL1(3)              RM, Round to -infinity
         DC    AL1(2)              RP, Round to +infinity
         DC    AL1(1)              RZ, Round to zero
         DC    AL1(0)              RNTE, Round to Nearest, ties to even
FPCMCT   EQU   *-FPCMODES          Count of FPC Modes to be tested
*
         EJECT
***********************************************************************
*
* Short BFP test data sets for Add testing.  
*
* The first test data set is used for tests of basic functionality,
* NaN propagation, and results from operations involving other than
* finite numbers.  
*
* The second test data set is used for testing boundary conditions
* using two finite non-zero values.  Each possible condition code 
* and type of result (normal, scaled, etc) is created by members of
* this test data set.  
*
* The third test data set is used for exhaustive testing of final 
* results across the five rounding modes available for the Add
* instruction.
*
***********************************************************************
         SPACE 2
***********************************************************************
*
* First input test data set, to test operations using non-finite or 
* zero inputs.  Member values chosen to validate Figure 19-13 on page 
* 19-16 of SA22-7832-10.  Each value in this table is tested against
* every other value in the table.  Ten entries means 100 result sets.
*
***********************************************************************
         SPACE 2
SBFPNFIN DS    0F                Inputs for short BFP non-finite tests
         DC    X'FF800000'         -inf
         DC    X'C0000000'         -2.0
         DC    X'80010000'         -Dnice
         DC    X'80000000'         -0
         DC    X'00000000'         +0
         DC    X'00010000'         -Dnice
         DC    X'40000000'         +2.0
         DC    X'7F800000'         +inf
         DC    X'FFCB0000'         -QNaN
         DC    X'7F8A0000'         +SNaN
SBFPNFCT EQU   (*-SBFPNFIN)/4    Count of short BFP in list
         SPACE 3
***********************************************************************
*
* Second input test data set.  These are finite pairs intended to
* trigger overflow, underflow, and inexact exceptions.  Each pair is
* added twice, once non-trappable and once trappable.  Trappable
* overflow or underflow yields a scaled result.  Trappable inexact 
* will show whether the Incremented DXC code is returned.  
*
* The following test cases are required:
* 1. Overflow
* 2. Underflow - normal inputs
* 3. Underflow - subnormal inputs
* 4. Normal - from subnormal inputs
* 5. Inexact - incremented
* 6. Inexact - truncated
*
***********************************************************************
         SPACE 2
SBFPIN   DS    0F                Inputs for short BFP finite tests
*
* Overflow on addition
*
         DC    X'7F7FFFFF'         +Nmax
         DC    X'7F7FFFFF'         +Nmax
*
* Underflow from sum of normals.  We will add a small normal to a
* negative smaller normal to generate a subnormal.
*
         DC    X'00FFFFFF'         Very small normal number
         DC    X'80800000'         Smaller normal negative
*
* Underflow from sum of subnormals.  We will add two subnormals.
*
         DC    X'00040000'         Subnormal, < +Dmax
         DC    X'00000F0F'         Smaller subnormal
*
* Normal result from sum of subnormals.  We will add two subnormals.
* The result will be greater than +Nmin
*
         DC    X'007FFFFF'         +Dmax
         DC    X'00000001'         +Dmin, result will be +Nmin
*
* Add a value to 1.0 such that the added digits are to the right of
* the right-most bit in the stored significand. The result will be 
* inexact, and incremented will be determined by the value of the 
* bits in the addend.  
*
         DC    X'3F800000'         Augend +1, aka 1.0b0
         DC    X'33F80000'         Addend 1.1111b-24
*                       ..Above addend is 1.154839992523193359375E-7
*                       ..nearest is away from zero, incremented.
*
         DC    X'3F800000'         Augend +1, aka 1.0b0
         DC    X'33780000'         Addend 1.1111b-25
*                       ..Above addend is 5.774199962615966796875E-8
*                       ..nearest is toward zero, truncated
*
SBFPCT   EQU   (*-SBFPIN)/4/2    Count of short BFP in list
         SPACE 3
***********************************************************************
*
* Third input test data set.  These are finite pairs intended to
* test all combinations of rounding mode for the sum and the 
* remainder.  Values are chosen to create a requirement to round
* to the target precision after the computation and to generate 
* varying results depending on the rounding mode in the FPCR.
*
* The result set will have cases that represent each of the following
*
* 1. Positive, nearest magnitude is toward zero.
* 2. Negative, nearest magnitude is toward zero.
* 3. Positive, nearest magnitude is away from zero.
* 4. Negative, nearest magnitude is away from zero.
* 5. Positive, tie, nearest even has greater magnitude
* 6. Negative, tie, nearest even has greater magnitude
* 7. Positive, tie, nearest even has lower magnitude
* 8. Negative, tie, nearest even has lower magnitude
*
* Round For Shorter precision correctness can be determined from the
* above test cases.  
*
***********************************************************************
         SPACE 2
SBFPINRM DS    0F                Inputs for short BFP rounding testing
*
* Add a value to 1.0 such that the added digits are to the right of
* the right-most bit in the stored significand. The result will be 
* inexact, and incremented will be determined by the value of the 
* bits in the addend.  
*
         DC    X'3F800000'         Augend +1, aka +1.0b0
         DC    X'337E0000'         Addend +1.111111b-25
         DC    X'BF800000'         Augend -1, aka -1.0b0
         DC    X'B37E0000'         Addend -1.111111b-25
*                       ..Above addend is 5.91389834880828857421875E-8
*                       ..nearest is toward zero, truncated
*
         DC    X'3F800000'         Augend +1, aka 1.0b0
         DC    X'33FF0000'         Addend +1.1111111b-24
         DC    X'BF800000'         Augend -1, aka -1.0b0
         DC    X'B3FF0000'         Addend -1.1111111b-24
*                       ..Above addend is 1.187436282634735107421875E-7
*                       ..nearest is away from zero, incremented.
*
         DC    X'3F800000'         Augend +1, aka +1.0b0
         DC    X'33800000'         Addend +1.0b-24
         DC    X'BF800000'         Augend -1, aka -1.0b0
         DC    X'B3800000'         Addend -1.0b-24
*                 ..Above addend is 5.9604644775390625E-8
*                 ..nearest is a tie, nearest even has lower magnitude
*
         DC    X'3F800000'         Augend +1, aka +1.0b0
         DC    X'34400000'         Addend +1.1b-23
         DC    X'BF800000'         Augend -1, aka -1.0b0
         DC    X'B4400000'         Addend -1.1b-23
*               ..Above addend is 1.78813934326171875E-7
*               ..nearest is a tie, nearest even has greater magnitude
SBFPRMCT EQU   (*-SBFPINRM)/4/2  Count of short BFP rounding tests
         EJECT
***********************************************************************
*
* Long BFP test data sets for Add testing.  
*
* The first test data set is used for tests of basic functionality,
* NaN propagation, and results from operations involving other than
* finite numbers.  
*
* The second test data set is used for testing boundary conditions
* using two finite non-zero values.  Each possible condition code 
* and type of result (normal, scaled, etc) is created by members of
* this test data set.  
*
* The third test data set is used for exhaustive testing of final 
* results across the five rounding modes available for the Add
* instruction.
*
***********************************************************************
         SPACE 2
***********************************************************************
*
* First input test data set, to test operations using non-finite or 
* zero inputs.  Member values chosen to validate Figure 19-13 on page 
* 19-16 of SA22-7832-10.  Each value in this table is tested against
* every other value in the table.  Ten entries means 100 result sets.
*
***********************************************************************
         SPACE 2
LBFPNFIN DS    0F                Inputs for long BFP testing
         DC    X'FFF0000000000000'         -inf
         DC    X'C000000000000000'         -2.0
         DC    X'8001000000000000'         -Dnice
         DC    X'8000000000000000'         -0
         DC    X'0000000000000000'         +0
         DC    X'0001000000000000'         +Dnice
         DC    X'4000000000000000'         +2.0
         DC    X'7FF0000000000000'         +inf
         DC    X'FFF8B00000000000'         -QNaN
         DC    X'7FF0A00000000000'         +SNaN
LBFPNFCT EQU   (*-LBFPNFIN)/8     Count of long BFP in list
         SPACE 3
***********************************************************************
*
* Second input test data set.  These are finite pairs intended to
* trigger overflow, underflow, and inexact exceptions.  Each pair is
* added twice, once non-trappable and once trappable.  Trappable
* overflow or underflow yields a scaled result.  Trappable inexact 
* will show whether the Incremented DXC code is returned.  
*
* The following test cases are required:
* 1. Overflow
* 2. Underflow - normal inputs
* 3. Underflow - subnormal inputs
* 4. Normal - from subnormal inputs
* 5. Inexact - incremented
* 6. Inexact - truncated
*
***********************************************************************
         SPACE 2
LBFPIN   DS    0D                Inputs for long BFP finite tests
*
* Overflow on addition
*
         DC    X'7FFFFFFFFFFFFFFF'  +Nmax
         DC    X'7FFFFFFFFFFFFFFF'  +Nmax
*
* Underflow from sum of normals.  We will add a small normal to a
* negative smaller normal to generate a subnormal.
*
         DC    X'001FFFFFFFFFFFFF'  Very small normal number
         DC    X'8010000000000000'  Smaller normal negative
*
* Underflow from sum of subnormals.  We will add two subnormals.
*
         DC    X'0008000000000000'  Subnormal, < +Dmax
         DC    X'0000F0F000000000'  Smaller subnormal
*
* Normal result from sum of subnormals.  We will add two subnormals.
* The result will be greater than +Nmin
*
         DC    X'000FFFFFFFFFFFFF'  +Dmax
         DC    X'0000000000000001'  +Dmin, result will be +Nmin
*
* Add a value to 1.0 such that the added digits are to the right of
* the right-most bit in the stored significand. The result will be 
* inexact, and incremented will be determined by the value of the 
* bits in the addend.  
*
         DC    X'3FF0000000000000'  Augend +1, aka 1.0b0
         DC    X'3CAF000000000000'  Addend 1.1111b-53
*    ..Above addend is 2.15105711021124079707078635692596435546875E-16
*    ..nearest is away from zero, incremented.
*
         DC    X'3FF0000000000000'  Augend +1, aka 1.0b0
         DC    X'3C9F000000000000'  Addend 1.1111b-54
*    ..Above addend is 1.075528555105620398535393178462982177734375E-16
*    ..nearest is toward zero, truncated.
*
LBFPCT   EQU   (*-LBFPIN)/8/2   Count of long BFP in list
         SPACE 3
***********************************************************************
*
* Third input test data set.  These are finite pairs intended to
* test all combinations of rounding mode for the sum and the 
* remainder.  Values are chosen to create a requirement to round
* to the target precision after the computation and to generate 
* varying results depending on the rounding mode in the FPCR.
*
* The result set will have cases that represent each of the following
*
* 1. Positive, nearest magnitude is toward zero.
* 2. Negative, nearest magnitude is toward zero.
* 3. Positive, nearest magnitude is away from zero.
* 4. Negative, nearest magnitude is away from zero.
* 5. Positive, tie, nearest even has greater magnitude
* 6. Negative, tie, nearest even has greater magnitude
* 7. Positive, tie, nearest even has lower magnitude
* 8. Negative, tie, nearest even has lower magnitude
*
* Round For Shorter precision correctness can be determined from the
* above test cases.  
*
***********************************************************************
         SPACE 2
LBFPINRM DS    0F
*
* Add a value to 1.0 such that the added digits are to the right of
* the right-most bit in the stored significand. The result will be 
* inexact, and incremented will be determined by the value of the 
* bits in the addend.  
*
         DC    X'3FF0000000000000'  Augend +1, aka +1.0b0
         DC    X'3C9FC00000000000'  Addend +1.111111b-54
         DC    X'BFF0000000000000'  Augend -1, aka -1.0b0
         DC    X'BC9FC00000000000'  Addend -1.111111b-54
* ..Above addend is 1.10154940724527250495157204568386077880859375E-16
* ..nearest is toward zero, truncated.
*
         DC    X'3FF0000000000000'  Augend +1, aka +1.0b0
         DC    X'3CAFE00000000000'  Addend +1.1111111b-53
         DC    X'BFF0000000000000'  Augend -1, aka -1.0b0
         DC    X'BCAFE00000000000'  Addend -1.1111111b-53
* ..Above addend is  2.21177243187042904537520371377468109130859375E-16
* ..nearest is away from zero, incremented.
*
         DC    X'3FF0000000000000'  Augend +1, aka +1.0b0
         DC    X'3CA0000000000000'  Addend +1.0b-53
         DC    X'BFF0000000000000'  Augend -1, aka -1.0b0
         DC    X'BCA0000000000000'  Addend -1.0b-53
*    ..Above addend is 1.1102230246251565404236316680908203125E-16
*    ..nearest is a tie, nearest even has lower magnitude
*
         DC    X'3FF0000000000000'  Augend +1, aka +1.0b0
         DC    X'3CB8000000000000'  Addend +1.1b-52
         DC    X'BFF0000000000000'  Augend -1, aka -1.0b0
         DC    X'BCB8000000000000'  Addend -1.1b-52
*    ..Above addend is 3.3306690738754696212708950042724609375E-16
*    ..nearest is a tie, nearest even has greater magnitude
*
*
LBFPRMCT EQU   (*-LBFPINRM)/8/2  Count of long BFP rounding tests
         EJECT
***********************************************************************
*
* Extended BFP test data sets for Add testing.  
*
* The first test data set is used for tests of basic functionality,
* NaN propagation, and results from operations involving other than
* finite numbers.  
*
* The second test data set is used for testing boundary conditions
* using two finite non-zero values.  Each possible condition code 
* and type of result (normal, scaled, etc) is created by members of
* this test data set.  
*
* The third test data set is used for exhaustive testing of final 
* results across the five rounding modes available for the Add
* instruction.
*
***********************************************************************
         SPACE 2
***********************************************************************
*
* First input test data set, to test operations using non-finite or 
* zero inputs.  Member values chosen to validate Figure 19-13 on page 
* 19-16 of SA22-7832-10.  Each value in this table is tested against
* every other value in the table.  Ten entries means 100 result sets.
*
***********************************************************************
         SPACE 2
XBFPNFIN DS    0F                Inputs for extended BFP testing
         DC    X'FFFF0000000000000000000000000000'   -inf
         DC    X'C0000000000000000000000000000000'   -2.0
         DC    X'80001000000000000000000000000000'   -Dnice
         DC    X'80000000000000000000000000000000'   -0
         DC    X'00000000000000000000000000000000'   +0
         DC    X'00001000000000000000000000000000'   +Dnice 
         DC    X'40000000000000000000000000000000'   +2.0
         DC    X'7FFF0000000000000000000000000000'   +inf
         DC    X'FFFF8B00000000000000000000000000'   -QNaN
         DC    X'7FFF0A00000000000000000000000000'   +SNaN
XBFPNFCT EQU   (*-XBFPNFIN)/16     Count of extended BFP in list
         SPACE 3
***********************************************************************
*
* Second input test data set.  These are finite pairs intended to
* trigger overflow, underflow, and inexact exceptions.  Each pair is
* added twice, once non-trappable and once trappable.  Trappable
* overflow or underflow yields a scaled result.  Trappable inexact 
* will show whether the Incremented DXC code is returned.  
*
* The following test cases are required:
* The following test cases are required:
* 1. Overflow
* 2. Underflow - normal inputs
* 3. Underflow - subnormal inputs
* 4. Normal - from subnormal inputs
* 5. Inexact - incremented
* 6. Inexact - truncated
*
***********************************************************************
         SPACE 2
XBFPIN   DS    0F                Inputs for extended BFP finite tests
*
* Overflow on addition
*
         DC    X'7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'  +Nmax
         DC    X'7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'  +Nmax
*
* Underflow from sum of normals.  We will add a small normal to a
* negative smaller normal to generate a subnormal.
*
         DC    X'0001FFFFFFFFFFFFFFFFFFFFFFFFFFFF'  Very small normal
         DC    X'80010000000000000000000000000000'  Smaller normal
*
* Underflow from sum of subnormals.  We will add two subnormals.
*
         DC    X'00008000000000000000000000000000'  Subnormal, < +Dmax
         DC    X'00000F0F000000000000000000000000'  Smaller subnormal
*
* Normal result from sum of subnormals.  We will add two subnormals.
* The result will be greater than +Nmin
*
         DC    X'0000FFFFFFFFFFFFFFFFFFFFFFFFFFFF'  +Dmax
         DC    X'00000000000000000000000000000001'  +Dmin
*                                   ...result will be +Nmin
*
* Add a value to 1.0 such that the added digits are to the right of
* the right-most bit in the stored significand. The result will be 
* inexact, and incremented will be determined by the value of the 
* bits in the addend.  
*
         DC    X'3FFF0000000000000000000000000000'  +1, aka 1.0b0
         DC    X'3F8EF000000000000000000000000000'  1.1111b-113
*    ..Above addend is 1.865744633625134732647978631879148339833785...
*                      ...97170865731413869070820510387420654296875E-34
*    ..nearest is away from zero, incremented.
*
         DC    X'3FFF0000000000000000000000000000'  +1, aka 1.0b0
         DC    X'3F8DF000000000000000000000000000'  1.1111b-114
*    ..Above addend is 9.328723168125673663239893159395741699168929...
*                      ...85854328657069345354102551937103271484375E-35
*    ..nearest is toward zero, truncated
*
XBFPCT   EQU   (*-XBFPIN)/16/2   Count of extended BFP in list 
         SPACE 3
***********************************************************************
*
* Third input test data set.  These are finite pairs intended to
* test all combinations of rounding mode for the sum and the 
* remainder.  Values are chosen to create a requirement to round
* to the target precision after the computation and to generate 
* varying results depending on the rounding mode in the FPCR.
*
* The result set will have cases that represent each of the following
*
* 1. Positive, nearest magnitude is toward zero.
* 2. Negative, nearest magnitude is toward zero.
* 3. Positive, nearest magnitude is away from zero.
* 4. Negative, nearest magnitude is away from zero.
* 5. Positive, tie, nearest even has greater magnitude
* 6. Negative, tie, nearest even has greater magnitude
* 7. Positive, tie, nearest even has lower magnitude
* 8. Negative, tie, nearest even has lower magnitude
*
* Round For Shorter precision correctness can be determined from the
* above test cases.  
*
***********************************************************************
         SPACE 2
XBFPINRM DS    0D
*
* Add a value to 1.0 such that the added digits are to the right of
* the right-most bit in the stored significand. The result will be 
* inexact, and incremented will be determined by the value of the 
* bits in the addend.  
*
         DC    X'3FFF0000000000000000000000000000'  +1, aka +1.0b0
         DC    X'3F8DFC00000000000000000000000000'  +1.111111b-114
         DC    X'BFFF0000000000000000000000000000'  -1, aka -1.0b0
         DC    X'BF8DFC00000000000000000000000000'  -1.111111b-114
*    ..Above addend is 9.554418083483552864769890574542412869310113...
*                  ...6454435273748231338686309754848480224609375E-35
*    ..nearest is toward zero
*
         DC    X'3FFF0000000000000000000000000000'  +1, aka +1.0b0
         DC    X'3F8EFE00000000000000000000000000'  +1.1111111b-113
         DC    X'BFFF0000000000000000000000000000'  -1, aka -1.0b0
         DC    X'BF8EFE00000000000000000000000000'  -1.1111111b-113
*    ..Above addend is 1.918406780541973213004978028746704946200062...
*                  ...18865204683510228278464637696743011474609375E-34
*    ..nearest is away from zero
*
         DC    X'3FFF0000000000000000000000000000'  +1, aka +1.0b0
         DC    X'3F8E0000000000000000000000000000'  +1.0000b-113
         DC    X'BFFF0000000000000000000000000000'  -1, aka -1.0b0
         DC    X'BF8E0000000000000000000000000000'  -1.0000b-113
*    ..Above addend is 9.629649721936179265279889712924636592690508...
*                  ...241076940976199693977832794189453125E-35
*    ..nearest is a tie, nearest even has lower magnitude
*
         DC    X'3FFF0000000000000000000000000000'  +1, aka +1.0b0
         DC    X'3F8F8000000000000000000000000000'  +1.1b-112
         DC    X'BFFF0000000000000000000000000000'  -1, aka -1.0b0
         DC    X'BF8F8000000000000000000000000000'  -1.1b-112
*    ..Above addend is 9.629649721936179265279889712924636592690508...
*                  ...241076940976199693977832794189453125E-35
*    ..nearest is a tie, nearest even has greater magnitude
*
XBFPRMCT EQU   (*-XBFPINRM)/16/2  Count of long BFP rounding tests
         EJECT
*
*  Locations for results
*
SBFPNFOT EQU   STRTLABL+X'1000'    Integer short non-finite BFP results
*                                  ..room for 110 tests, 100 used
SBFPNFFL EQU   STRTLABL+X'1700'    FPCR flags and DXC from short BFP
*                                  ..room for 110 tests, 100 used
*
SBFPOUT  EQU   STRTLABL+X'1E00'    Integer short BFP finite results
*                                  ..room for 16 tests, 6 used
SBFPFLGS EQU   STRTLABL+X'1F00'    FPCR flags and DXC from short BFP
*                                  ..room for 16 tests, 6 used
*
SBFPRMO  EQU   STRTLABL+X'2000'    Short BFP rounding mode test results
*                                  ..Room for 16, 8 used.  
SBFPRMOF EQU   STRTLABL+X'2300'    Short BFP rounding mode FPCR results
*                                  ..Room for 16, 8 used.  
*                                  ..next location starts at X'2500'
*
LBFPNFOT EQU   STRTLABL+X'4000'    Integer long non-finite BFP results
*                                  ..room for 100 tests, 100 used
LBFPNFFL EQU   STRTLABL+X'4D00'    FPCR flags and DXC from long BFP
*                                  ..room for 100 tests, 100 used
*
LBFPOUT  EQU   STRTLABL+X'5400'    Integer long BFP finite results
*                                  ..room for 16 tests, 6 used
LBFPFLGS EQU   STRTLABL+X'5600'    FPCR flags and DXC from long BFP
*                                  ..room for 16 tests, 6 used
*
LBFPRMO  EQU   STRTLABL+X'5700'    Long BFP rounding mode test results
*                                  ..Room for 16, 8 used.  
LBFPRMOF EQU   STRTLABL+X'5C00'    Long BFP rounding mode FPCR results
*                                  ..Room for 16, 8 used.  
*                                  ..next location starts at X'5E00'
*
XBFPNFOT EQU   STRTLABL+X'8000'    Integer ext'd non-finite BFP results
*                                  ..room for 100 tests, 100 used
XBFPNFFL EQU   STRTLABL+X'8D00'    FPCR flags and DXC from ext'd BFP
*                                  ..room for 100 tests, 100 used
*
XBFPOUT  EQU   STRTLABL+X'9400'    Extended BFP finite results
*                                  ..room for 16 tests, 6 used
XBFPFLGS EQU   STRTLABL+X'9600'    FPCR flags and DXC from ext'd BFP
*                                  ..room for 16 tests, 6 used
*
XBFPRMO  EQU   STRTLABL+X'9700'    Ext'd BFP rounding mode test results
*                                  ..Room for 16, 8 used.  
XBFPRMOF EQU   STRTLABL+X'9C00'    Ext'd BFP rounding mode FPCR results
*                                  ..Room for 16, 8 used.  
*                                  ..next location starts at X'9E00'
*
ENDLABL  EQU   STRTLABL+X'9E00'
         PADCSECT ENDLABL
         END
