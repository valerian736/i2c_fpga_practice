library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
  
entity Clock_Divider is
    port ( clk,reset: in std_logic; clock_out: out std_logic);
end Clock_Divider;
  
architecture bhv of Clock_Divider is

    constant divider_val_1hz: integer:=27000000/2;
    signal count: integer:=0;
    signal tmp : std_logic := '0';
  
begin
  
clk_1hz : process( clk, reset )
    begin

        if reset = '1' then
            count <= 0;
            tmp <= '0';
        elsif rising_edge(clk) then
            if count = divider_val_1hz - 1 then
                count <= 0;
                tmp <= not tmp;
            else
                count <= count + 1;
            end if;

        end if;

        clock_out <= tmp;
end process;




  
end bhv;