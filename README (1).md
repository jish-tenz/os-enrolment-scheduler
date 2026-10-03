# VU Enrolment Scheduler: OS Resource Allocation Simulation

![Scheduler output](scheduler-output.png)

At the start of every semester, thousands of students hit the university enrolment system at once. Each request needs a prerequisite check, a timetable clash check and a seat check, and they all compete for the same limited resources.

This project models that rush as an **operating system scheduling problem**: each enrolment request is a process competing for **CPU time**, **memory** and **class seats**. I built the simulation as a working **Bash shell script** that produces a real, repeatable execution log.

---

## How the scheduler works

| Constraint | What I used | Why |
|---|---|---|
| **CPU time** | Round Robin, quantum = 2 | A long timetable check can't block a quick seat check |
| **Memory** | Admission control with bounded retries | A request only loads if there's enough memory free. If it never fits, it's rejected cleanly instead of waiting forever |
| **Class seats** | Fail-fast check on arrival | A full class can't be fixed by more CPU or memory, so it's rejected straight away without wasting resources |

## Enrolment request → OS process

| Enrolment | OS equivalent |
|---|---|
| Request arriving | Process entering the ready queue |
| Prerequisite / clash / seat checks | CPU burst |
| Student record held while processing | Memory footprint |
| One action runs at a time | Single-CPU time sharing |
| Request table (ID, arrival, burst, memory, seat) | Process control block |

## Results

The simulation shows every outcome:
- ✅ **Completed:** requests that got CPU, memory and a seat
- ⏳ **Waited:** requests held back while memory was busy
- ❌ **Rejected (no seat):** failed the capacity check on arrival
- ❌ **Rejected (memory starvation):** a very memory-heavy request that never fit, even with fair CPU scheduling. This is the key finding: **CPU and memory have to be planned together**

## Why Round Robin?

- **FCFS:** one long request blocks everyone behind it
- **Shortest-Job-First:** needs burst times in advance, and long requests can starve
- **Priority:** no fair priority order between enrolment types
- **Round Robin:** fair, responsive, and needs no advance knowledge ✔️

---

**Tools:** Linux · Bash shell scripting
**Team:** Jenish Gurung & Hoang Gia Phat Nguyen, Victoria University (Operating Systems unit)
**My role:** system design, the shell script, and the execution log and failure case evidence

[LinkedIn](https://www.linkedin.com/in/jenish-gurung-7ba907326) · [GitHub](https://github.com/jish-tenz)
