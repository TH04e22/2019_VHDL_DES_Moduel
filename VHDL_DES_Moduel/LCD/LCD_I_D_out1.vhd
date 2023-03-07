-- Name: LCD_I_D_out1
-- Author: Terry Huang
-- Description:
-- LCD(HD44780) Sender which ensure every instruction work out well
LIBRARY IEEE;
    USE IEEE.std_logic_1164.all;
    USE IEEE.std_logic_unsigned.all;

ENTITY LCD_I_D_out1 IS
    PORT(
        LCD_CLK, LCD_RESET : in std_logic;
        RW, RS : in std_logic;
        DBi : in std_logic_vector( 7 downto 0 );
        DB_io : inout std_logic_vector( 7 downto 0 );
        DBo : out std_logic_vector( 7 downto 0 );
        RSo, RWo, Eo : out std_logic;
		  LCD_wait_No : out std_logic_vector( 6 downto 0 );
        LCD_Done : out boolean
    );
END ENTITY;

ARCHITECTURE ARCH OF LCD_I_D_out1 IS
    Signal RWS : std_logic;
    Signal LCD_runs :std_logic_vector( 2 downto 0 );
    Signal LCD_wait_cntr : std_logic_vector( 6 downto 0 );
BEGIN
    RWo <= RWS;
    DB_io <= DBi WHEN RWS = '0' Else "ZZZZZZZZ";
    LCD_wait_No <= LCD_wait_cntr;
    
    PROCESS( LCD_CLK, LCD_RESET )
    BEGIN
        IF LCD_RESET ='0' THEN
            DBo <= (DBo'range => '0' );
            RSo <= RS;
            RWS <= RW;
            Eo <= '0';
            LCD_Done <= false;
            LCD_runs <= "000";
        ELSIF rising_edge( LCD_CLK ) THEN
            CASE LCD_runs IS
                WHEN "000" =>            -- LCD enable
                    Eo <= '1';
                    LCD_runs <= "001";
                WHEN "001" =>
                    Eo <= '0';
                    IF RW = '1' THEN     -- If it is read instruction, then output data
                        DBo <= DB_io;
                    END IF;
                    LCD_runs <= "010";
                WHEN "010" =>            -- test whether the LCD is still busy
                    RSo <= '0';
                    RWS <= '1';
                    LCD_runs <= "011";
                WHEN "011" =>
                    LCD_wait_cntr <= "0000000";
                    Eo <= '1';
                    LCD_runs <= "100";
                WHEN "101" =>            -- DB_io(7) is "1" means LCD is still busy 
                    LCD_wait_cntr <= LCD_wait_cntr + 1;
                    LCD_runs <= "10" & DB_io(7);
                    Eo <= DB_io(7);
                WHEN others =>
                    LCD_Done <= true;
            END CASE;
        END IF;
    END PROCESS;
END ARCH;