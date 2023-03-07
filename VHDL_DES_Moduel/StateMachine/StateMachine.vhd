-- Name: StateMachine.vhd
-- Author: Terry Huang
-- Description:
-- Get user's input and communicate DES module, LCD module
-- Change State
LIBRARY IEEE;
    USE IEEE.std_logic_1164.all;
    USE IEEE.std_logic_unsigned.all;
    USE IEEE.numeric_std.all;
LIBRARY STD;
    USE STD.standard.all;

ENTITY StateMachine IS
    PORT (
        Clk : in std_logic;                               -- Button input
        Input, Delete, Clear, Submit : in std_logic;
        char : in std_logic_vector( 7 downto 0 );
        Result_Text : in std_logic_vector( 63 downto 0 ); -- DES Module
        Des_EN  : out std_logic;
        ED_Sel  : out std_logic;
        Plain_Text : out std_logic_vector( 63 downto 0 );
        Key : out std_logic_vector( 63 downto 0 );
        LCD_RESETo : out std_logic;                      -- LCD Module
        RW, RS : out std_logic;
        DB : out std_logic_vector( 7 downto 0 );
        LCD_Done : in boolean
    );
END ENTITY;

ARCHITECTURE BEHAVIOR OF StateMachine IS
    -- StateMachine
    TYPE Machine_State IS ( Init, Input_Text, Input_Key, Encrypt, Input_Decrypt,Decrypt, Show );
    Constant Input_Prompt : string( 1 to 16 ) :=   "PlainText:      ";
    Constant Key_Prompt : string( 1 to 16 ) :=     "Key:            ";
    Constant Cypher_Prompt : string( 1 to 16 ) :=  "Cypher:         ";
    Constant Decrypt_Prompt : string( 1 to 16 ) := "Decyption:      ";
    Constant Empty_Prompt : string( 1 to 16 ) :=   "                ";
    Constant User_Empty_Input : string( 1 to 8 ) := "        ";    
    Signal M_State : Machine_State := Init;
    Signal User_Input : std_logic_vector( 63 downto 0 );
    Signal Input_Cntr : integer range 0 to 8;  -- Count words which user input

    -- DES Module
    Constant Des_Clock_Limit : integer := 5;
    Signal Des_Clock_Cntr : integer := 0;  -- clock Des_EN holds

    -- LCD
    TYPE LCD_State IS ( LCD_Init, LCD_Execute, LCD_Stay,  LCD_Input,
                    LCD_Delete, LCD_Clear, LCD_Prompt_Line );
    TYPE LCD_T IS ARRAY( 0 to 15 ) of std_logic_vector( 7 downto 0 );
    Constant LCD_IT : LCD_T := (  -- LCD initial table 5 x 8 two row
        "00111000", "00111000", "00111000", "00111000", "00001001",
        "00000001", "00000110", "00001111", "00000001", "01000001",
        "01000010", "01000011", "01000100", "00000000", "00000000",
        "00000000" );
    Signal Ins_Execntr : std_logic_vector( 4 downto 0 ) := "00000";
    Signal L_State : LCD_State;
    Signal L_Last_State : LCD_State;
    Signal LCD_Init_Cntr : integer range 0 to 15;
    Signal LCD_Reset : std_logic;
    Signal LCD_En : std_logic := '1';
    Signal LCD_Line : std_logic; -- 0 is first line, 1 is second
    Signal LCD_Line_Begin : std_logic_vector( 3 downto 0 );
    Signal First_Line : std_logic_vector( 127 downto 0 );
    Signal Second_Line : std_logic_vector( 127 downto 0 );

    -- Button
    Signal Reset : std_logic := '0';
    Signal Input_Enable : boolean := false;
    Signal Delete_Enable : boolean := false;
    Signal Clear_Enable : boolean := false;
    Signal Submit_Enable : boolean := false;
    Signal Input_Buffer : std_logic_vector( 1 downto 0 ) := "11";
    Signal Delete_Buffer : std_logic_vector( 1 downto 0 ) := "11";
    Signal Clear_Buffer : std_logic_vector( 1 downto 0 ) := "11";
    Signal Submit_Buffer : std_logic_vector( 1 downto 0 ) := "11";

    FUNCTION Str_To_StdV8( Text : string ) RETURN std_logic_vector IS -- string convert to std_logic_vector( 127 downto 0 )
        Variable result : std_logic_vector( Text'right * 8 - 1 downto 0 ) := (others=>'0');
    BEGIN
        FOR I IN Text'left To Text'right LOOP
            result( result'left-8*(I-1) downto result'left-7-8*(I-1) ) := 
                std_logic_vector(to_unsigned(character'pos(Text(I)),8));
        END LOOP;
        RETURN result;
    END Str_To_StdV8;
BEGIN
    LCD_RESETo <= LCD_Reset;
    PROCESS( Clk, Reset ) IS
    BEGIN
        IF Reset = '0' THEN
            L_State <= LCD_Init;
            M_State <= Init;
            LCD_Init_Cntr <= 0;
            LCD_Line_Begin <= "0000";
            LCD_Reset <= '0';
            LCD_En <= '0';
            Reset <= '1';
        ELSIF rising_edge( Clk ) THEN
            Input_Buffer <= Input_Buffer(0) & Input;
            Delete_Buffer <= Delete_Buffer(0) & Delete;
            Clear_Buffer <= Clear_Buffer(0) & Clear;
            Submit_Buffer <= Submit_Buffer(0) & Submit;

            IF LCD_En = '1' THEN
                CASE L_State IS
                    WHEN LCD_Init =>
                        IF LCD_Init_Cntr > 8 THEN
                            L_State <= LCD_Stay;
                        ELSE
                            DB <= LCD_IT( LCD_Init_Cntr );
                            RS <= '0';
                            RW <= '0';
                            LCD_Reset <= '0';
                            LCD_Init_Cntr <= LCD_Init_Cntr + 1;
                            L_State <= LCD_Execute;
                            L_Last_State <= LCD_Init;
                        END IF;
                    WHEN LCD_Input =>
                        IF Ins_Execntr = "00000" THEN
                            RS <= '1';
                            LCD_Reset <= '0';
                            RW <= '0';
                            DB <= char;
                            Ins_Execntr <= Ins_Execntr + 1;
                            L_Last_State <= LCD_Input;
                            L_State <= LCD_Execute;
                        ELSE
                            Ins_Execntr <= (others=>'0');
                            L_State <= LCD_Stay;
                        END IF;
                    WHEN LCD_Delete =>
                        IF Ins_Execntr < "00011" THEN
                            CASE Ins_Execntr IS
                                WHEN "00000" =>
                                    RS <= '0';
                                    RW <= '0';
                                    DB <= "00010000";
                                WHEN "00001" =>
                                    RS <= '1';
                                    RW <= '0';
                                    DB <= "00100000";
                                WHEN others =>
                                    RS <= '0';
                                    RW <= '0';
                                    DB <= "00010000";
                            END CASE;
                            LCD_Reset <= '0';
                            Ins_Execntr <= Ins_Execntr + 1;
                            L_Last_State <= LCD_Delete;
                            L_State <= LCD_Execute;
                        ELSE
                            Ins_Execntr <= (others=>'0');
                            L_State <= LCD_Stay;
                        END IF;
                    WHEN LCD_Clear =>
                        IF Ins_Execntr = "00000" THEN
                            RS <= '0';
                            RW <= '0';
                            DB( 5 downto 0 ) <= "00" & LCD_Line_Begin;
                            DB(6) <= '1';
                            DB(7) <= '1';
                            LCD_Reset <= '0';
                            Ins_Execntr <= Ins_Execntr + 1;
                            L_Last_State <= LCD_Clear;
                            L_State <= LCD_Execute;
                        ELSIF Ins_Execntr < "01001" THEN
                            RS <= '1';
                            RW <= '0';
                            DB <= "00100000";
                            LCD_Reset <= '0';
                            Ins_Execntr <= Ins_Execntr + 1;
                            L_Last_State <= LCD_Clear;
                            L_State <= LCD_Execute;
                        ELSIF Ins_Execntr = "01001" THEN
                            RS <= '0';
                            RW <= '0';
                            DB( 5 downto 0 ) <= "00" & LCD_Line_Begin;
                            DB(6) <= '1';
                            DB(7) <= '1';
                            LCD_Reset <= '0';
                            Ins_Execntr <= Ins_Execntr + 1;
                            L_Last_State <= LCD_Clear;
                            L_State <= LCD_Execute;
                        ELSE
                            Ins_Execntr <= (others=>'0');
                            L_State <= LCD_Stay;
                        END IF;
                    WHEN LCD_Prompt_Line =>
                        IF Ins_Execntr = "11111" THEN
                            RS <= '0';
                            RW <= '0';
                            DB( 5 downto 0 ) <= "000000";
                            DB(6) <= LCD_Line;
                            DB(7) <= '1';
                            LCD_Reset <= '0';
                            Ins_Execntr <= Ins_Execntr + 1;
                            L_Last_State <= LCD_Prompt_Line;
                            L_State <= LCD_Execute;
                        ELSIF Ins_Execntr < "01111" THEN
                            RS <= '1';
                            RW <= '0';
                            IF LCD_Line = '0' THEN
                                DB <= First_Line( 127 - Conv_Integer( ins_execntr ) * 8  downto 127 - 7- Conv_Integer( ins_execntr ) * 8 );
                            ELSE
                                DB <= Second_Line( 127 - Conv_Integer( ins_execntr ) * 8  downto 127 - 7- Conv_Integer( ins_execntr ) * 8 );
                            END IF;
                            LCD_Reset <= '0';
                            Ins_Execntr <= Ins_Execntr + 1;
                            L_Last_State <= LCD_Prompt_Line;
                            L_State <= LCD_Execute;
                        ELSIF Ins_Execntr = "01111" THEN
                            RS <= '0';
                            RW <= '0';
                            DB( 5 downto 0 ) <= "00" & LCD_Line_Begin;
                            DB(6) <= '1';
                            DB(7) <= '1';
                            LCD_Reset <= '0';
                            IF LCD_Line = '0' THEN
                                LCD_Line <= '1';
                                Ins_Execntr <= "11111";
                            ELSE
                                Ins_Execntr <= Ins_Execntr + 1;
                            END IF;
                            L_Last_state <= LCD_Prompt_Line;
                            L_State <= LCD_Execute;
                        ELSE
                            Ins_Execntr <= (others=>'0');
                            L_State <= LCD_Stay;
                        END IF;
                    WHEN LCD_Stay =>
                        LCD_En <= '0';    
                    WHEN LCD_Execute =>
                        IF LCD_Reset = '1' THEN
                            IF LCD_Done THEN
                                L_State <= L_Last_State;
                                LCD_Reset <= '0';
                            END IF;
                        ELSE
                            LCD_Reset <= '1';
                        END IF;
                END CASE;
            ELSIF LCD_En = '0' THEN
                IF M_State = Input_Text OR M_State = Input_Key OR M_State = Input_Decrypt THEN
                    IF Input_Buffer = "10" THEN
                        Input_Enable <= true;
                    ELSIF Delete_Buffer = "10" THEN
                        Delete_Enable <= true;
                    ELSIF Clear_Buffer = "10" THEN
                        Clear_Enable <= true;
                    ELSIF Submit_Buffer = "10" THEN
                        Submit_Enable <= true;
                    END IF;
                END IF;

                CASE M_State IS
                    WHEN Init =>    -- Initial all configure
                        -- Text buffer
                        Input_Cntr <= 0;
                        User_Input <= Str_To_StdV8( User_Empty_Input );
                        
                        -- LCD Module Initial
                        LCD_Reset <= '0';
                        LCD_En <= '1';
                        LCD_Line <= '0';
                        LCD_Line_Begin <= "0000";
								Ins_Execntr <= "11111";
                        First_Line <= Str_To_StdV8( Input_Prompt );
                        Second_Line <= Str_To_StdV8( Empty_Prompt );
                        

                        -- Des module control
                        Des_EN <= '1';
                        ED_Sel <= 'X';
                        Plain_Text <= (others=>'0');
                        Key <= (others=>'0');

                        M_State <= Input_Text;
                        L_State <= LCD_Prompt_Line;
                    WHEN Input_Text =>    -- Show prompt and let user input text
                        IF Submit_Enable = true THEN
                            -- Text buffer
                            Plain_Text <= User_Input;
                            Input_Cntr <= 0;
                            User_Input <= Str_To_StdV8( User_Empty_Input );

                            -- LCD
                            First_Line <= Str_To_StdV8( Key_Prompt );
                            Second_Line <= Str_To_StdV8( Empty_Prompt );
                            LCD_Reset <= '0';
                            LCD_Line <= '0';
                            LCD_Line_Begin <= "0000";
                            LCD_En <= '1';

                            -- State Transition
									 Ins_Execntr <= "11111";
                            L_State <= LCD_Prompt_Line;
                            M_State <= Input_Key;
                            Submit_Enable <= false;
                        ELSE
                            IF Input_Enable = true THEN
                                IF Input_Cntr < 8 THEN
                                    -- Text buffer
                                    User_Input( User_Input'left - 8*Input_Cntr downto User_Input'left - 8*Input_Cntr - 7 ) <=
                                        char( 7 downto 0 );
                                    Input_Cntr <= Input_Cntr + 1;
                                    
                                    -- LCD Module
                                    LCD_En <= '1';
                                    L_State <= LCD_Input;
                                END IF;
                                Input_Enable <= false;
                            ELSIF Delete_Enable = true THEN
                                IF Input_Cntr > 0 THEN
                                    -- Text buffer
                                    Input_Cntr <= Input_Cntr - 1;
                                    User_Input( User_Input'left - 8*(Input_Cntr-1) downto User_Input'left - 8*(Input_Cntr-1) - 7 ) <=
                                        "00000000";

                                    -- LCD Module
                                    LCD_En <= '1';
                                    L_State <= LCD_Delete;
                                END IF;
                                Delete_Enable <= false;
                            ELSIF Clear_Enable = true THEN
                                -- Text Buffer
                                Input_Cntr <= 0;
                                User_Input <= Str_To_StdV8( User_Empty_Input );

                                -- LCD
                                LCD_En <= '1';
                                L_State <= LCD_Clear;
                                Clear_Enable <= false;
                            END IF;
                        END IF;
                    WHEN  Input_Key =>    -- Show prompt and let user input key
                        IF Submit_Enable = true THEN
                            -- Text buffer
                            First_Line <= Str_To_StdV8( Cypher_Prompt );
                            Second_Line <= Str_To_StdV8( Key_Prompt );
                            Key <= User_Input;

                            -- Des module control
                            Des_Clock_Cntr <= 0;
                            Des_EN <= '0'; -- Process enable
                            ED_Sel <= '0'; -- encrypt
                            M_State <= Encrypt;
                            Submit_Enable <= false;
                        ELSE
                            IF Input_Enable = true THEN
                                IF Input_Cntr < 8 THEN
                                    -- Text buffer
                                    User_Input( User_Input'left - 8*Input_Cntr downto User_Input'left - 8*Input_Cntr - 7 ) <=
                                        char( 7 downto 0 );
                                    Input_Cntr <= Input_Cntr + 1;

                                    -- LCD Module
                                    LCD_En <= '1';
                                    L_State <= LCD_Input;
                                END IF;
                                Input_Enable <= false;
                            ELSIF Delete_Enable = true THEN
                                IF Input_Cntr > 0 THEN
                                    -- Text buffer
                                    Input_Cntr <= Input_Cntr - 1;
                                    User_Input( User_Input'left - 8*(Input_Cntr-1) downto User_Input'left - 8*(Input_Cntr-1) - 7 ) <=
                                        "00000000";
                                    
                                    -- LCD Module
                                    LCD_En <= '1';
                                    L_State <= LCD_Delete;
                                END IF;
                                Delete_Enable <= false;
                            ELSIF Clear_Enable THEN
                                -- Text Buffer
                                Input_Cntr <= 0;
                                User_Input <= Str_To_StdV8( User_Empty_Input );

                                -- LCD
                                LCD_En <= '1';
                                L_State <= LCD_Clear;
                                Clear_Enable <= false;
                            END IF;
                        END IF;
                    WHEN Encrypt => -- Encrypt process
                        IF Des_Clock_Cntr < Des_Clock_Limit THEN
                            Des_Clock_Cntr <= Des_Clock_Cntr + 1;
                        ELSE
                            Input_Cntr <= 0;
                            User_Input <= Str_To_StdV8( User_Empty_Input );

                            First_Line( 71 downto 8 ) <= Result_Text;
                            Plain_Text <= Result_Text;
									 Ins_Execntr <= "11111";
                            L_State <= LCD_Prompt_Line;
                            LCD_Line <= '0';
                            LCD_Line_Begin <= "0100";
                            LCD_En <= '1';

                            Des_EN <= '1';
                            M_State <= Input_Decrypt;
                        END IF;
                    WHEN Input_Decrypt => -- Show encrypt result and input decrypt 
                        IF Submit_Enable = true THEN
                            -- Text buffer
                            First_Line <= Str_To_StdV8( Decrypt_Prompt );
                            Second_Line <= Str_To_StdV8( Empty_Prompt );
                            Key <= User_Input;

                            -- Des module control
                            Des_Clock_Cntr <= 0;
                            Des_EN <= '0'; -- Process enable
                            ED_Sel <= '1'; -- decrypt
                            M_State <= Decrypt;
                            Submit_Enable <= false;
                        ELSE
                            IF Input_Enable = true THEN
                                IF Input_Cntr < 8 THEN
                                    -- Text buffer
                                    User_Input( User_Input'left - 8*Input_Cntr downto User_Input'left - 8*Input_Cntr - 7 ) <=
                                        char( 7 downto 0 );
                                    Input_Cntr <= Input_Cntr + 1;

                                    -- LCD Module
                                    LCD_En <= '1';
                                    L_State <= LCD_Input;
                                END IF;
                                Input_Enable <= false;
                            ELSIF Delete_Enable = true THEN
                                IF Input_Cntr > 0 THEN
                                    -- Text buffer
                                    Input_Cntr <= Input_Cntr - 1;
                                    User_Input( User_Input'left - 8*(Input_Cntr-1) downto User_Input'left - 8*(Input_Cntr-1) - 7 ) <=
                                        "00000000";
                                    
                                    -- LCD Module
                                    LCD_En <= '1';
                                    L_State <= LCD_Delete;
                                END IF;
                                Delete_Enable <= false;
                            ELSIF Clear_Enable = true THEN
                                -- Text Buffer
                                Input_Cntr <= 0;
                                User_Input <= Str_To_StdV8( User_Empty_Input );

                                -- LCD
                                LCD_En <= '1';
                                L_State <= LCD_Clear;
                                Clear_Enable <= false;
                            END IF;
                        END IF;
                    WHEN Decrypt => -- Decrypt process
                        IF Des_Clock_Cntr < Des_Clock_Limit THEN
                            Des_Clock_Cntr <= Des_Clock_Cntr + 1;
                        ELSE
                            Second_Line( 127 downto 64 ) <= Result_Text;
									 Ins_Execntr <= "11111";
                            L_State <= LCD_Prompt_Line;
                            LCD_Line <= '0';
                            LCD_Line_Begin <= "1000";
                            LCD_En <= '1';

                            Des_EN <= '1';
                            M_State <= Show;
                        END IF;
                    WHEN Show =>    -- Show the decrypt result
                        IF Submit_Buffer = "10" THEN
                            -- Text buffer
                            Input_Cntr <= 0;
                            User_Input <= Str_To_StdV8( User_Empty_Input );
                            
                            -- LCD Module
                            LCD_Reset <= '0';
                            LCD_En <= '1';
                            LCD_Line <= '0';
                            LCD_Line_Begin <= "0000";
                            First_Line <= Str_To_StdV8( Input_Prompt );
                            Second_Line <= Str_To_StdV8( Empty_Prompt );
                            

                            -- Des module control
                            Des_EN <= '1';
                            ED_Sel <= 'X';
                            Plain_Text <= (others=>'0');
                            Key <= (others=>'0');

                            M_State <= Input_Text;
									 Ins_Execntr <= "11111";
                            L_State <= LCD_Prompt_Line;
                        END IF;
                END CASE;
            END IF;
        END IF;
    END PROCESS;
END BEHAVIOR;