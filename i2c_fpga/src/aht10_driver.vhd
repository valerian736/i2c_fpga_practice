library ieee ;
    use ieee.std_logic_1164.all ;
    use ieee.numeric_std.all ;

entity aht10 is
    generic(
        addr     : std_logic_vector(6 downto 0) := "0111000";  
        clk_freq : integer := 27000000;
        bus_speed : integer := 400000                     
    );
    port (
        clk, rst      : in    std_logic;
        scl, sda      : inout std_logic;
        i2c_ack_error : out   std_logic;
        temp          : out   std_logic_vector(19 downto 0);   
        hum           : out   std_logic_vector(19 downto 0)     
    ) ;
end aht10 ;

architecture arch of aht10 is
    component i2c_master IS
        GENERIC(
            input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
            bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
        PORT(
            clk       : IN     STD_LOGIC;                    --system clock
            reset_n   : IN     STD_LOGIC;                    --active low reset
            ena       : IN     STD_LOGIC;                    --latch in command
            addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
            rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
            data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
            busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
            data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
            ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
            sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
            scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
    end component;

    type aht10_state is (s_start, s_callibrate, s_trigger, s_read, s_output);

    
    constant ONE_MS        : integer := clk_freq / 1000;
    constant POWERUP_DELAY : integer := 40 * ONE_MS;  
    constant MEASURE_DELAY : integer := 80 * ONE_MS;  

   
    signal reset_n     : std_logic;
    signal i2c_ena     : std_logic := '0';
    signal i2c_addr    : std_logic_vector(6 downto 0) := (others => '0');
    signal i2c_rw      : std_logic := '0';
    signal i2c_data_wr : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_busy    : std_logic;
    signal i2c_data_rd : std_logic_vector(7 downto 0);
    signal i2c_ack_err : std_logic;
    signal busy_prev   : std_logic := '0';

    signal state    : aht10_state := s_start;
    signal cal      : std_logic := '0';
    signal temp_raw : std_logic_vector(19 downto 0) := (others => '0');
    signal hum_raw  : std_logic_vector(19 downto 0) := (others => '0');

begin

    
    reset_n       <= not rst;
    i2c_ack_error <= i2c_ack_err;

    master : i2c_master
        generic map(
            input_clk => clk_freq,
            bus_clk   => bus_speed
        )
        port map(
            clk       => clk,
            reset_n   => reset_n,
            ena       => i2c_ena,
            addr      => i2c_addr,
            rw        => i2c_rw,
            data_wr   => i2c_data_wr,
            busy      => i2c_busy,
            data_rd   => i2c_data_rd,
            ack_error => i2c_ack_err,
            sda       => sda,
            scl       => scl
        );

    fsm : process(clk)
        variable busy_cnt : integer range 0 to 7 := 0;
        variable counter  : integer range 0 to MEASURE_DELAY := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= s_start;
                i2c_ena  <= '0';
                i2c_rw   <= '0';
                cal      <= '0';
                busy_prev<= '0';
                busy_cnt := 0;
                counter  := 0;
                temp_raw <= (others => '0');
                hum_raw  <= (others => '0');
            else
                case state is


                    when s_start =>
                        if counter < POWERUP_DELAY then
                            counter := counter + 1;
                        else
                            counter := 0;
                            state   <= s_callibrate;
                        end if;


                    when s_callibrate =>
                        busy_prev <= i2c_busy;
                        if busy_prev = '0' and i2c_busy = '1' then
                            busy_cnt := busy_cnt + 1;
                        end if;
                        case busy_cnt is
                            when 0 =>
                                i2c_ena     <= '1';
                                i2c_addr    <= addr;
                                i2c_rw      <= '0';
                                i2c_data_wr <= x"E1";
                            when 1 =>
                                i2c_data_wr <= x"08";
                            when 2 =>
                                i2c_data_wr <= x"00";
                            when 3 =>
                                i2c_ena <= '0';
                                if i2c_busy = '0' then
                                    busy_cnt := 0;
                                    cal      <= '1';
                                    state    <= s_trigger;
                                end if;
                            when others =>
                                busy_cnt := 0;
                        end case;


                    when s_trigger =>
                        busy_prev <= i2c_busy;
                        if busy_prev = '0' and i2c_busy = '1' then
                            busy_cnt := busy_cnt + 1;
                        end if;
                        case busy_cnt is
                            when 0 =>
                                i2c_ena     <= '1';
                                i2c_addr    <= addr;
                                i2c_rw      <= '0';
                                i2c_data_wr <= x"AC";
                            when 1 =>
                                i2c_data_wr <= x"33";
                            when 2 =>
                                i2c_data_wr <= x"00";
                            when 3 =>
                                i2c_ena <= '0';
                                if i2c_busy = '0' then
                                    busy_cnt := 0;
                                    counter  := 0;
                                    state    <= s_read;
                                end if;
                            when others =>
                                busy_cnt := 0;
                        end case;

                    ----------------------------------------------------------
                     --   b0 status
                    --   b1 hum[19:12]
                    --   b2 hum[11:4]
                    --   b3 hum[3:0] | temp[19:16]
                    --   b4 temp[15:8]
                    --   b5 temp[7:0]
                    ----------------------------------------------------------
                    when s_read =>
                        if counter < MEASURE_DELAY then
                            counter := counter + 1;
                        else
                            busy_prev <= i2c_busy;
                            if busy_prev = '0' and i2c_busy = '1' then
                                busy_cnt := busy_cnt + 1;
                               
                                case busy_cnt is
                                    when 3 => hum_raw(19 downto 12) <= i2c_data_rd;               -- b1
                                    when 4 => hum_raw(11 downto 4)  <= i2c_data_rd;               -- b2
                                    when 5 => hum_raw(3 downto 0)   <= i2c_data_rd(7 downto 4);   -- b3
                                              temp_raw(19 downto 16)<= i2c_data_rd(3 downto 0);   -- b3
                                    when 6 => temp_raw(15 downto 8) <= i2c_data_rd;               -- b4
                                    when others => null;
                                end case;
                            end if;

                            case busy_cnt is
                                when 0 =>
                                    i2c_ena  <= '1';
                                    i2c_addr <= addr;
                                    i2c_rw   <= '1';
                                when 6 =>
                                    i2c_ena <= '0';  
                                    if i2c_busy = '0' then
                                        temp_raw(7 downto 0) <= i2c_data_rd;  -- b5
                                        busy_cnt := 0;
                                        counter  := 0;
                                        state    <= s_output;
                                    end if;
                                when others =>
                                    null;
                            end case;
                        end if;


                    when s_output =>
                        temp  <= temp_raw;
                        hum   <= hum_raw;
                        state <= s_trigger;

                end case;
            end if;
        end if;
    end process;

end architecture ;