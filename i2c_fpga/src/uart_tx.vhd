library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic(
        clock_freq : integer:= 27000000;
        baud_rate : integer:= 115200
    );

    port (
        clk : in std_logic;
        rst : in std_logic;
        tx_data  : in std_logic_vector(7 downto 0);
        tx_stb : in std_logic;
        tx_busy : out std_logic;
        tx_line : out std_logic
    );


end uart_tx;

architecture behavioural of uart_tx is
    type uart_state is (s_idle, s_start, s_data, s_stop);
    constant cycle : integer:= clock_freq/baud_rate - 1;
    signal state : uart_state:= s_idle;
    signal msg : std_logic_vector(7 downto 0):= "00000000";
    signal cnt : integer range 0 to cycle - 1 := 0;
    signal idx : integer range 0 to 7:= 0;

begin
    FSM_PROC : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= s_idle;
                tx_line <= '1';
                idx <= 0;
                cnt <= 0;
                msg <= "00000000";
                tx_busy <= '0';

            else
                case state is
    
                    when s_idle =>
                        tx_line <= '1';
                        if tx_stb = '1' then
                            msg <= tx_data;
                            tx_busy <= '1';
                            state <= s_start;
                            
                        end if;
                    when s_start =>
                        tx_line <= '0';
                        if cnt = cycle then
                            cnt <= 0;
                            state <= S_data;
                        else
                            cnt <= cnt +1;
                        end if;
                    when s_data =>
                        tx_line <= msg(idx);
                        if cnt = cycle then 
                            cnt <= 0;
                            if idx = 7 then
                                idx <= 0;
                                state <= s_stop;
                            else
                                idx <= idx + 1;
                                
                            end if;
                        else 
                            cnt <= cnt + 1;
                        end if ;

                    when s_stop => 
                        tx_line <= '0';
                        if cnt = cycle then
                            cnt <= 0;
                            tx_busy <= '0';
                            state <= s_idle;
                        else
                            cnt <= cnt + 1;
                            
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;

