----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:19:46 07/18/2014 
-- Design Name: 
-- Module Name:    new_buffer_handler - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity new_buffer_handler_simple is
port(
clk250_i : in std_logic; -- was 125
rst_i : in std_logic;
trig_i : in std_logic_vector(3 downto 0); -- was DO_HOLD
trig_buffer_o : out std_logic_vector(1 downto 0); -- unconnected on top - leave for consistency 
clear_i : in std_logic; -- used to generate RELEASE
clear_buffer_i : in  std_logic_vector(1 downto 0); -- used to generate RELEASE
digitize_o : out std_logic; -- new: a 100 ns pulse from the time either of the pairs go into second hold - should work as there is a holdoff. 
digitize_buffer_o : out std_logic_vector(1 downto 0); -- 2 bits for legacy - needs only one to indicate which
		    															-- of the pairs is being digitized - NEW signal
digitize_source_o : out std_logic_vector(3 downto 0);  -- needs to be kept 100 ns.
HOLD_o : out std_logic_vector(3 downto 0); --was below
--HOLD_A : out std_logic;
--HOLD_B : out std_logic;
--HOLD_C : out std_logic;
--HOLD_D : out std_logic;
buffer_status_o : out std_logic_vector(3 downto 0); 
dead_o : out std_logic


);
end new_buffer_handler_simple;

architecture Behavioral of new_buffer_handler_simple is


signal flag41 : std_logic := '0'; -- to "generate" the /3 clock.
signal FIRST_I : std_logic := '0';
signal REJECTED : std_logic;
signal DO_HOLD : std_logic;
signal DO_HOLD_VEC : std_logic_vector(1 downto 0) := "00";
signal FROZEN : std_logic_vector(1 downto 0) := "00";


--signal veto_hold_counter0 : std_logic_vector(4 downto 0) := "11001";
--signal veto_hold_counter1 : std_logic_vector(4 downto 0) := "11001";

--signal veto_hold_counter : std_logic_vector(4 downto 0) := "11001";
signal veto_hold_counter : std_logic_vector(4 downto 0) := "00000";



type state_t is (SAMPLING, HOLD_1, HOLD_BOTH, WAIT_FOR_NEW_DATA);

signal state0, next_state0 : state_t := SAMPLING;
signal state1, next_state1 : state_t := SAMPLING;

signal count : std_logic_vector(1 downto 0):= "00";
signal st_counter0 : std_logic_vector(4 downto 0):= (others =>'0');
signal st_counter1: std_logic_vector(4 downto 0):= (others =>'0');

constant WAIT_FOR_SECOND_LAB : std_logic_vector(4 downto 0):= "10110"; -- 88 ns between first and second hold to guarantee overlap 
constant WAIT_FOR_NEW_DATA_TC : std_logic_vector(4 downto 0):= "11010"; -- 104 ns wait to guarantee filling up a full LAB

signal st_counterI_0 : std_logic_vector(4 downto 0):= (others =>'0');
signal st_counterII_0 : std_logic_vector(4 downto 0):= (others =>'0');
signal st_counterI_1: std_logic_vector(4 downto 0):= (others =>'0');
signal st_counterII_1: std_logic_vector(4 downto 0):= (others =>'0');

signal digitize_counter: std_logic_vector(4 downto 0):= (others =>'0');
signal trig_latched: std_logic_vector(3 downto 0):= (others =>'0');



signal FIRST_A : std_logic := '0';
signal FIRST_C : std_logic := '0';


signal start_digitize_0 : std_logic := '0';
signal start_digitize_1 : std_logic := '0';


signal HOLD_A :  std_logic;
signal HOLD_B :  std_logic;
signal HOLD_C :  std_logic;
signal HOLD_D :  std_logic;


signal BUSY_I :  std_logic; -- no longer used. keep for possible debugging
signal BUSY_II : std_logic; -- no longer used. keep for possible debugging




signal RELEASE :  std_logic_vector(1 downto 0); -- indicates that a digitization is finished - needs to know which pair...
																-- now done using clear_buffers

signal START_HOLDING :  std_logic_vector(1 downto 0); -- indicates that one specific pair is just being held - useful to mark events appropriately.
																	  -- unused - kept for debugging


begin



trig_buffer_o <= "00"; -- unused
HOLD_o <=HOLD_D & HOLD_C & HOLD_B & HOLD_A;
-- latching process
process(clk250_i)
begin
	if rst_i = '1' then
		DO_HOLD<= '0';
		dead_o <= '0';
		RELEASE <= "00";
	elsif rising_edge(clk250_i) then
		DO_HOLD <= trig_i(0) or trig_i(1) or trig_i(2) or trig_i(3);
		if ((trig_i(0) or trig_i(1) or trig_i(2) or trig_i(3)) = '1') then trig_latched <= trig_i; end if;
		dead_o <= (HOLD_D or HOLD_C) and (HOLD_B or HOLD_A); -- if even only one of the chip is held, we need to wait to start issuing triggers.
		if clear_i = '1' then
			case clear_buffer_i(0) is 
			when '0' => RELEASE(0)<= '1';
			when '1' => RELEASE(1)<= '1';
			when others => RELEASE <= "00";
			end case;
		else
			RELEASE <= "00";
		end if;
	end if;
end process;


-- Main process to control which pair gets the hold. Needs release info to know when a pair is again available.
-- if both are available it continuously ping-pongs.

process(clk250_i)
begin
	if rst_i = '1' then
		START_HOLDING <= "00";
		DO_HOLD_VEC <= "00"; -- also the DO_HOLD_VECTOR need to be single clock pulses
		REJECTED<='0'; -- REJECTED indicates no available buffer for triggering.
		FIRST_I <= '0';
		digitize_source_o<= (others => '0');
		veto_hold_counter<=(others => '0');
		FROZEN <=(others => '0');
	elsif rising_edge(clk250_i) then
		START_HOLDING <= "00";
		DO_HOLD_VEC <= "00"; -- also the DO_HOLD_VECTOR need to be single clock pulses
		REJECTED<='0'; -- REJECTED indicates no available buffer for triggering.
--		FIRST_I <= not FIRST_I;
		if FROZEN /= "11" and veto_hold_counter >0 then veto_hold_counter<= veto_hold_counter - 1; end if; -- new data is recorded on one ASIC
																																			-- as long as not both are frozen			
--		if veto_hold_counter0 >0 then veto_hold_counter0<= veto_hold_counter0 - 1; end if;
--		if veto_hold_counter1 >0 then veto_hold_counter1<= veto_hold_counter1 - 1; end if;
		if DO_HOLD ='1' then
			if FIRST_I = '0' then
				if FROZEN(0) = '0' and veto_hold_counter = "00000" then 
					FROZEN(0)<='1';
					DO_HOLD_VEC(0)<='1';
					FIRST_I <= not FIRST_I; -- change first only if it effectively triggered
					digitize_source_o<=trig_latched;
					START_HOLDING <= "01";
					veto_hold_counter<= "11001"; --when frozen, the last ~100ns of data are already recorded - need to wait until a new hold is issued
				elsif  FROZEN(1) = '0' and veto_hold_counter = "00000" then 
					FROZEN(1)<='1';
					DO_HOLD_VEC(1)<='1';
					FIRST_I <= not FIRST_I; -- change first only if it effectively triggered
					digitize_source_o<=trig_latched;
					START_HOLDING <= "10";
					veto_hold_counter<= "11001";
				else
					REJECTED<='1'; -- if both frozen, ignore the hold
				end if;
			else
				if FROZEN(1) = '0' and veto_hold_counter = "00000" then 
					FROZEN(1)<='1';
					DO_HOLD_VEC(1)<='1';
					FIRST_I <= not FIRST_I; -- change first only if it effectively triggered
					digitize_source_o<=trig_latched;
					START_HOLDING <= "10";
					veto_hold_counter<= "11001";
				elsif  FROZEN(0) = '0' and veto_hold_counter = "00000" then 
					FROZEN(0)<='1';
					DO_HOLD_VEC(0)<='1';
					FIRST_I <= not FIRST_I; -- change first only if it effectively triggered
					digitize_source_o<=trig_latched;
					START_HOLDING <= "01";
					veto_hold_counter<= "11001";
				else
					REJECTED<='1'; -- if both frozen, ignore the hold
				end if;			
			end if;
		end if;
			if state0 = SAMPLING then FROZEN(0)<='0'; end if;
			if state1 = SAMPLING then FROZEN(1)<='0'; end if;
			
--
--			if RELEASE(0) = '1' then FROZEN(0)<='0';  end if; -- note: if both RELEASE and HOLD arrive at the same time, the trigger is also ignored - might be worth to modify to get thisd marginal case on.
--			if RELEASE(1) = '1' then FROZEN(1)<='0';  end if;
	end if;
end process;


process(clk250_i)
begin
	if rst_i = '1' then
		BUSY_I<= '0';
		state0<=SAMPLING;
		HOLD_A<='0';
		HOLD_B<='0';
		FIRST_A<= '1'; -- it effectively means A is the first to be held
		st_counterI_0 <= (others => '0');
		st_counterII_0 <= (others => '0');
		start_digitize_0 <= '0';
	elsif rising_edge(clk250_i) then
	start_digitize_0 <= '0';
	case state0 is
		when SAMPLING => 
					BUSY_I<= '0';
					if DO_HOLD_VEC(0) = '0' then
						state0 <= SAMPLING;
					else
						state0 <= HOLD_1;
						st_counterI_0 <= (others => '0');
					end if;
					HOLD_A<='0';
					HOLD_B<='0';
--					FIRST_A <= not FIRST_A; -- for now always uses A as the first lab to be held
		when HOLD_1 =>
					BUSY_I<= '1';
					HOLD_A<=FIRST_A;
					HOLD_B<=not FIRST_A;	
					BUSY_I<= '1';
					if st_counterI_0< WAIT_FOR_SECOND_LAB then
						st_counterI_0 <= st_counterI_0 + 1;
						state0 <= HOLD_1;							
					else
						state0 <= HOLD_BOTH;
						HOLD_A<='1';
						HOLD_B<='1';
						st_counterI_0 <= (others => '0');
						start_digitize_0 <= '1';
					end if;
		when HOLD_BOTH =>
					BUSY_I<= '1';
					HOLD_A<='1';
					HOLD_B<='1';
					if RELEASE(0) = '1'  then
--					if FROZEN(0) = '0' then
					  state0 <= WAIT_FOR_NEW_DATA;
					else
					  state0 <= HOLD_BOTH;
					end if;
		when WAIT_FOR_NEW_DATA =>
					BUSY_I<= '1';
					if st_counterII_0< WAIT_FOR_NEW_DATA_TC then
						st_counterII_0 <= st_counterII_0 + 1;
						state0 <= WAIT_FOR_NEW_DATA;
					else
						state0 <= SAMPLING;
						st_counterII_0 <= (others => '0');
					end if;
		when OTHERS => NULL; 

	end case;

	end if;
end process;



process(clk250_i)
begin
		if rst_i = '1' then
			BUSY_II<= '0';
			state1<=SAMPLING;
			HOLD_C<='0';
			HOLD_D<='0';
			FIRST_C<= '1';
			st_counterI_1 <= (others => '0');
			st_counterII_1 <= (others => '0');
			start_digitize_1 <= '0';
		elsif rising_edge(clk250_i) then
		start_digitize_1 <= '0';
	case state1 is
		when SAMPLING => 
					BUSY_II<= '0';
					if DO_HOLD_VEC(1) = '0' then
						state1 <= SAMPLING;
					else
						state1 <= HOLD_1;
						st_counterI_1 <= (others => '0');
					end if;
					HOLD_C<='0';
					HOLD_D<='0';
--					FIRST_C <= not FIRST_C; -- for now always uses C as the first lab to be held
		when HOLD_1 =>
					BUSY_II<= '1';
					HOLD_C<=FIRST_C;
					HOLD_D<=not FIRST_C;	
					BUSY_II<= '1';
					if st_counterI_1< WAIT_FOR_SECOND_LAB then
						st_counterI_1 <= st_counterI_1 + 1;
						state1 <= HOLD_1;							
					else
						state1 <= HOLD_BOTH;
						HOLD_C<='1';
						HOLD_D<='1';
						st_counterI_1 <= (others => '0');
						start_digitize_1 <= '1';
					end if;
		when HOLD_BOTH =>
					BUSY_II<= '1';
					HOLD_C<='1';
					HOLD_D<='1';
					if RELEASE(1) = '1'  then
--					if FROZEN(1) = '0' then
					  state1 <= WAIT_FOR_NEW_DATA;
					else
					  state1 <= HOLD_BOTH;
					end if;
		when WAIT_FOR_NEW_DATA =>
					BUSY_II<= '1';
					if st_counterII_1< WAIT_FOR_NEW_DATA_TC then
						st_counterII_1 <= st_counterII_1 + 1;
						state1 <= WAIT_FOR_NEW_DATA;
					else
						state1 <= SAMPLING;
						st_counterII_1 <= (others => '0');
					end if;
		when OTHERS => NULL; 

	end case;

	end if;
end process;

process(clk250_i)
begin
	if rst_i = '1' then
		digitize_counter<=(others =>'0');
		digitize_o <= '0';
		digitize_buffer_o <= "00";
		buffer_status_o<= (others =>'0');		
	elsif rising_edge(clk250_i) then
		if digitize_counter > 0 then
			digitize_o <= '1';
			digitize_counter <= digitize_counter - 1;
		elsif (start_digitize_0 or start_digitize_1) = '1' then
			if start_digitize_0 = '1' then -- it should work as there is guaranteed holdoff
				digitize_buffer_o <= "00";
				buffer_status_o<= "000" & not FIRST_A; -- FIRST_A = 1 indicates A is the first - that is marked as 0
			else
				digitize_buffer_o <= "01";
				buffer_status_o<= "000" & not FIRST_C;
			end if;
			digitize_o <= '1';
			digitize_counter <= "11001";
		else
			digitize_o <= '0';
		end if;
	end if;
end process;
		



end Behavioral;




