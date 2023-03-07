-- Name: Freq_Div3.vhd
-- Author: Terry Huang
-- Description: Frequency divider
LIBRARY IEEE;
    USE IEEE.std_logic_1164.all;
    USE IEEE.std_logic_unsigned.all;

ENTITY Freq_Div3 IS
    PORT (
        CLK, RESET, P_N_edge : in std_logic;
            F1_S, F2_S, F3_S : in std_logic_vector( 3 downto 0 );
            F1,   F2,   F3   : out std_logic
    );
END ENTITY;

ARCHITECTURE BEHAVIOR OF Freq_Div3 IS
    Constant F5S : std_logic_vector( 7 downto 0 ) := "11111111"; -- Divide 255
    Signal FCLK : std_logic;
    Signal  F5F : std_logic_vector( 7 downto 0 ) := ( others => '0');
    Signal F16F : std_logic_vector( 15 downto 0 ) := ( others => '0');
BEGIN
    FCLK <= CLK XNOR P_N_edge; -- Positive or Negetive edge trigger
    F1 <= F16F( Conv_Integer(F1_S) );
    F2 <= F16F( Conv_Integer(F2_S) );
    F3 <= F16F( Conv_Integer(F3_S) );

    PROCESS( FCLK, RESET )
    BEGIN
        IF RESET = '0' THEN
            F5F <= ( others => '0');
            F16F <= ( others => '0');
        ELSIF rising_edge( FCLK ) THEN
            IF F5F = F5S THEN
                F5F <= (others=>'0');
                F16F <= F16F + 1;
            ELSE
                F5F <= F5F + 1;
            END IF;
        END IF;
    END PROCESS;
END BEHAVIOR;