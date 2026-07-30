# Task 4 (EC4) - AXI4 Verification and UVM-SystemC Co-simulation

This repository contains the delivery for Task 4 from Group 5 for the MP-6160 High-Level Design course.

## Repository Organization (Role B)
The project structure is organized as follows to separate responsibilities and facilitate continuous integration:
- `rtl/`: Verilog design files (AXI4 RAM module and scaffolds).
- `tb/`: Verification Environment (SystemVerilog/UVM).
  - `tb/uvm/`: UVM Classes (Item, Driver, Monitor, Sequencer, Agent, Env, and base Test).
  - `tb/interfaces/`: `axi4_if` interface definition including SVA (SystemVerilog Assertions) as protocol checkers.
  - `tb/tb_top.sv`: Top module that instantiates interfaces and DUTs.
- `systemc/`: SystemC accelerator files and end-to-end model.
- `scripts/`: Makefiles and TCL scripts to automate Vivado simulation.

## Requirements and Compilation (Role D)
> [!NOTE] 
> **Role D**: Please add dependencies (Vivado XSim, gcc, etc.) and the exact instructions to run the integration scripts here.

## Module Organization

### Verification Modules (Role B)
The UVM environment isolates the AXI4 Full protocol verification from the processing logic. The base architecture includes:
- **`axi4_if`**: Unified interface with integrated assertions (SVA) that act as protocol "police" (verifying valid handshakes, `$stable` rule while `valid && !ready`, and ensuring bursts do not cross 4KB boundaries).
- **Dummy Slave**: A `dummy_slave` module that serves as a temporary DUT substitute. It keeps the `ready` signals high to allow the BFM master to inject stimuli without prematurely blocking Role C and D's tests.
- **Active UVM Environment**: Includes a Driver that injects physical `axi4_item` into the bus, and a passive Monitor that observes read/write addresses and data to feed the Scoreboard.

### RTL Modules (Role E)
> [!NOTE]
> **Role E**: Describe the internal architecture of the Verilog RAM module, its AXI4 slave, response handling (SLVERR), and the estimated latency cost here.

### SystemC Modules (Role A)
> [!NOTE]
> **Role A**: Describe the TLM proxy adaptation, temporal adjustment, and transfer `delay` manipulation here.

## Diagrams

### Block Diagram (Role E)
> [!NOTE]
> **Role E**: Insert the RTL architecture block diagram here.

### Sequence Diagram (Role D)
> [!NOTE]
> **Role D**: Insert the DPI/VPI bridge sequence diagram here.

## Results Obtained

### UVM Verification (Role C)
> [!NOTE]
> **Role C**: Include the UVM coverage report, scoreboard behavior with error cases (4KB rule), and the synthetic golden model.

### End-to-End and Comparison (Role A)
> [!NOTE]
> **Role A**: Demonstrate bit-exact validation against the processed 1080p RAW RGB image.

## AI Usage Declaration
*In accordance with the course incentive, the group declares the use of Artificial Intelligence tools for the following tasks:*

- **Role B:** Google Gemini (Antigravity AI) was used through conversational prompts to:
  1) Discuss the skeleton structure for the `axi4_if` interface.
  2) Organize this README template.
- **Role A:** `[To be completed]`
- **Role C:** `[To be completed]`
- **Role D:** `[To be completed]`
- **Role E:** `[To be completed]`
