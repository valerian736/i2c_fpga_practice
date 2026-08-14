library IEEE;
use Ieee.std_logic_1164.ALL;

entity top is
    port(
        clk, rst: in std_logic;
        --btn: in std_logic;
        --output: out std_logic_vector(7 downto 0);
        test_led: out std_logic;
        tx: out std_logic
        --rx: in std_logic
);
end top;

architecture beavioral of top is
    
    component Clock_Divider is
    port ( clk,reset: in std_logic; clock_out: out std_logic);
    end component;

    component uart_tx is
    port (
        clk : in std_logic;
        rst : in std_logic;
        tx_data  : in std_logic_vector(7 downto 0);
        tx_stb : in std_logic;
        tx_busy : out std_logic;
        tx_line : out std_logic
        
    );
    end component;

    constant msg: std_logic_vector(7 downto 0):= b"00100001";
    signal clockout_1hz: std_logic := '0';
    signal clockout_prev: std_logic := '0';
    signal busy_line: std_logic := '0'; 
    signal stb: std_logic := '0';


begin 

    clock: Clock_Divider port map(clk, rst, clockout_1hz);
    uart_test: uart_tx port map(clk, rst, msg, stb, busy_line,tx);

    edge_detect : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                clockout_prev <= '0';
            else
                clockout_prev <= clockout_1hz;     
            end if;
            
        end if;
    end process;

    stb <= clockout_1hz and (not clockout_prev);

    test_led <= clockout_1hz;

end architecture;