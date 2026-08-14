library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_ctrl is
    port (

        clk,rst : in std_logic;
        stb : in std_logic;
        datas : in std_logic_vector(55 downto 0);
        tx_busy: in std_logic;
        tx_out: out std_logic_vector(7 downto 0);
        tx_stb: out std_logic;
        
    );
end uart_ctrl;

architecture arch of uart_ctrl is
    type ctrl_state is (s_idle, s_shift, s_busy);
    constant MSG_MAX : integer := datas'length - 8;

    signal tx_ptr    : integer range 0 to MSG_MAX := MSG_MAX;
    signal tx_busy_i : std_logic := '0';
    signal tx_cont   : std_logic := '0';
    signal state : ctrl_state := s_idle;

begin

    FSM_PROC : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= s_idle;
                tx_busy_i  <= '0';
                tx_cont    <= '0';
                tx_stb     <= '0';
                tx_out     <= (others => '0');
                tx_ptr     <= MSG_MAX;

    
            else
                case state is
    
                    when s_idle =>

                    when s_shift =>
                    when s_busy => 
                        
    
                end case;
    
            end if;
        end if;
    end process;

end architecture;