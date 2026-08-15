library IEEE;
use Ieee.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port(
        clk, rst: in std_logic;
        --btn: in std_logic;
        --output: out std_logic_vector(7 downto 0);
        test_led: out std_logic;
    scl, sda : inout std_logic;
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
        --scl, sda : inout std_logic;
        tx_line : out std_logic
        
    );
    end component;
    
    component uart_ctrl is
    port (

        clk,rst : in std_logic;
        stb : in std_logic;
        datas : in std_logic_vector(95 downto 0);
        tx_busy: in std_logic;
        tx_out: out std_logic_vector(7 downto 0);
        tx_stb: out std_logic
        
    );
    end component;

    component aht10 is
    port (
        clk, rst      : in    std_logic;
        scl, sda      : inout std_logic;
        i2c_ack_error : out   std_logic;
        temp          : out   std_logic_vector(19 downto 0);   
        hum           : out   std_logic_vector(19 downto 0)     
    ) ;
    end component ;

    function ascii_digit(d : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(d + 48, 8));
    end function;

    signal msg: std_logic_vector(7 downto 0);
    signal test_msg: std_logic_vector(95 downto 0):= (others => '0'); 
    signal clockout_1hz: std_logic := '0';
    signal clockout_prev: std_logic := '0';
    signal busy_line: std_logic := '0'; 
    signal stb: std_logic := '0';
    signal ctl_stb: std_logic := '0';

    signal i2c_err: std_logic := '1';
    signal temp_r: std_logic_vector (19 downto 0) := (others => '0');
    signal hum_r: std_logic_vector (19 downto 0) := (others => '0');

    signal hum_pct_x10 : std_logic_vector(10 downto 0);  
    signal temp_c_x10  : std_logic_vector(11 downto 0);  

    constant space_ascii : std_logic_vector(7 downto 0) := x"20";

begin 

    clock: Clock_Divider port map(clk, rst, clockout_1hz);
    uart_test: uart_tx port map(clk, rst, msg, ctl_stb, busy_line,tx);
    uart_controller: uart_ctrl port map(clk, rst, stb, test_msg, busy_line, msg, ctl_stb);
    sensor: aht10 port map(clk, rst, scl, sda, i2c_err, temp_r, hum_r); 

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

    convert_raw : process(clk)
        variable h_prod : unsigned(29 downto 0);   -- raw(20b) * 1000 (10b) = 30b
        variable t_prod : unsigned(30 downto 0);   -- raw(20b) * 2000 (11b) = 31b
        variable t_int  : signed(11 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                --msg <= x"68656C6C6F2120";
                hum_pct_x10 <= (others => '0');
                temp_c_x10 <= (others => '0');
            else
                h_prod := unsigned(hum_r) * to_unsigned(1000, 10);
                hum_pct_x10 <= std_logic_vector(resize(h_prod(29 downto 20), 11));

                t_prod := unsigned(temp_r) * to_unsigned(2000, 11);
                t_int  := signed(resize(t_prod(30 downto 20), 12)) - to_signed(500, 12);
                temp_c_x10 <= std_logic_vector(t_int);

            end if;      
        end if;
    end process;

    pack_message : process(clk)
        variable h : integer;
        variable t : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                test_msg <= (others => '0');
            else
                h := to_integer(unsigned(hum_pct_x10));     
                t := to_integer(signed(temp_c_x10)); 

                test_msg <=
                    ascii_digit((h/100) mod 10)     &           
                    ascii_digit((h/10)  mod 10)     &           
                    x"2E"                           &           
                    ascii_digit( h mod 10)          & 
                    x"25"                           &
                    x"20"                           &
                    ascii_digit((t/100) mod 10)     &
                    ascii_digit((t/10)  mod 10)     &
                    x"2E"                           &
                    ascii_digit((t mod 10))         &
                    --x"25"                           &           
                    x"0D"                           &           
                    x"0A";                                    
            end if;
        end if;
    end process;

    stb <= clockout_1hz and (not clockout_prev);

    test_led <= clockout_1hz;

end architecture;