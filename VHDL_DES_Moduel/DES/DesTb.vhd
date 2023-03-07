-- Name: DesTb.vhd
-- Author: Terry Huang
-- Description: DES module test bench
LIBRARY IEEE;
    USE IEEE.std_logic_1164.all;
    USE IEEE.numeric_std.all;

ENTITY DesTb IS
END ENTITY;

ARCHITECTURE SIM OF DesTb IS
    Constant frequency : integer := 50e6; -- 50 MHz
    Constant ClockPeriod : time := 1000 ms / frequency;
    Signal Clock : std_logic := '0';
    Signal En : std_logic := '1';
    Signal ED_Sel : std_logic := '0';
    Signal Input : std_logic_vector( 1 to 64 ) := x"1122334455667788";
    Signal Key : std_logic_vector( 1 to 64 ) := x"1122334455667788";
    Signal Output : std_logic_vector( 1 to 64 ) := (others => 'X');
BEGIN
    -- Testbench provides clocks
    Clock <= not Clock after ClockPeriod / 2;

    -- Device Under Test
    i_DES_module : ENTITY work.DES_module(BEHAVIOR)
    PORT MAP(
        Clk => Clock,
        En => En,
        ED_Sel => ED_Sel,
        Input => Input,
        Key => Key,
        Output => Output
    );

    -- Signal Generation
    PROCESS IS
    BEGIN
        WAIT UNTIL rising_edge(Clock);
        WAIT UNTIL rising_edge(Clock);
        En <= not En;
        WAIT FOR 100 ns;
        En <= not En;
        WAIT FOR 100 ns;
        Input <= Output;
        ED_Sel <= '1';
        En <= not En;
        WAIT FOR 100 ns;
        En <= not En;
        WAIT;
    END PROCESS;
END SIM;