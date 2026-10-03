Student Name: Jenish Gurung | Student ID: s8210611
Student Name: Hoang Gia Phat Nguyen | Student ID: s8174754

Assessment: VU Enrolment System

# Enrolment System Design & Reasoning

## 1. System Context

At the beginning of each semester, the VU online enrolment system experiences a large surge in student activity. Students attempt to enrol in subjects, swap tutorials, check seat availability and finalise their timetables within a limited period of time. While these actions may appear simple to users, each request triggers several background operations such as prerequisite checks, timetable clash detection, class capacity validation and student record updates.

Because many requests arrive at nearly the same time, the system must manage limited resources efficiently. Processing these requests consumes CPU time and memory, and every enrolment also depends on whether a seat is still available in the selected class. As a result, some requests may need to wait, while others may be rejected if system constraints cannot be satisfied.

In this project, the enrolment platform is modelled as an operating system environment where enrolment requests behave like processes competing for shared resources. The scheduler is responsible for determining whether a request can run immediately, remain in a waiting state, or be rejected due to limitations such as insufficient memory or unavailable class capacity.

## 1a. Operating System Evolution and Social Impact of Scheduling Design

The challenges faced by the VU enrolment system closely resemble issues that operating systems have dealt with throughout their development. Early batch operating systems processed jobs strictly in the order they arrived. Although simple, this approach often resulted in long jobs delaying every task behind them. In an enrolment system, a similar situation could occur if a large validation request prevented smaller enrolment requests from being processed in a reasonable time.

As operating systems evolved, time-sharing systems such as CTSS, Multics and early UNIX introduced scheduling techniques that allowed multiple processes to share CPU resources more fairly. One of the most influential approaches was Round Robin scheduling, where each process receives a fixed amount of CPU time before the next process is given an opportunity to run. This idea directly influenced the scheduling strategy used in our simulation because it helps prevent long-running tasks from dominating system resources.

Modern operating systems go beyond CPU scheduling and must consider multiple resources simultaneously. Mobile devices, cloud platforms and enterprise systems continuously make decisions involving memory, storage, networking and other constraints. Similarly, our enrolment scheduler must manage CPU time, memory availability and class capacity at the same time to ensure the system remains responsive and reliable under heavy demand.

These design decisions also have an important social impact. A poorly designed enrolment system could create unfair outcomes where some students consistently receive access simply because their requests happen to arrive first. By using Round Robin scheduling together with admission control, the system aims to provide a fairer allocation of resources while still maintaining correctness and stability. In this way, operating system design is not only about technical efficiency but also about ensuring that users receive a fair and dependable service experience.

## 2. Enrolment Actions as Operating System Processes

| Enrolment concept | OS equivalent |
|---|---|
| An enrolment request arriving | A process arriving in the ready/new queue |
| Prerequisite / clash / capacity check | The process's required CPU burst |
| Student record held in memory while a request is processed | The process's memory footprint while resident |
| "Only one enrolment action executes at a time" | Single-CPU, time-shared execution |
| Seat availability | A non-preemptible admission gate, checked once at arrival |

Each enrolment request is represented internally as a row in a
"process table" (parallel arrays: `IDS`, `ARRIVAL`, `CPU_BURST`,
`MEM_NEED`, `CAP_FLAG`), directly mirroring how an OS process control
block stores PID, arrival time, and resource requirements.

## 3. System Constraints and Their Effect on Outcomes

**CPU processing time.** Only one request can be executing at any
instant (per the assignment's system assumption). We use **Round
Robin** with a fixed quantum of 2 time units, so a long-running
validation (e.g. a 6-unit timetable check) cannot block short requests
(e.g. a 1-unit seat check) indefinitely - it is preempted and requeued
after 2 units, guaranteeing every ready request gets CPU time within a
bounded number of rounds. This directly satisfies the brief's
requirement to "avoid blocking short requests unnecessarily."

**Memory availability.** The system has a fixed shared memory pool
(100 units in our simulation). Unlike CPU, several requests can be
memory-resident (holding their partially processed record) at the same
time even though only one runs on the CPU at once - this models real
multiprogramming, where the degree of concurrency is bounded by memory,
not by CPU. A request is only admitted into memory if enough is free at
that moment; if not, it retries on a bounded schedule (`MAX_WAIT_ROUNDS
= 3`) before being rejected. This constraint alone can reject a request
that would otherwise be perfectly schedulable on the CPU - exactly what
happens to REQ_11 in our simulation (see Section 5 and
`failure_case_explanation_s8210611.txt`).

**Class capacity.** This is checked once, at arrival, before a request
is even considered for memory. It is binary and non-negotiable: no
amount of free CPU or memory can fix a full class. Checking it first
means the system "fails fast" and never wastes CPU/memory admitting a
request that cannot succeed regardless - satisfying "prevent invalid
enrolments."

## 4. Reasoning Table (Executable / Waiting / Rejected)

| Request | Arrival | CPU | Mem | Seat | Outcome | Justification |
|---|---|---|---|---|---|---|
| REQ_01 | 0 | 4 | 20 | Yes | **Executed → Completed** | Capacity OK; memory available immediately (100 free) |
| REQ_02 | 0 | 6 | 30 | Yes | **Executed → Completed** | Capacity OK; memory available immediately (80 free after REQ_01) |
| REQ_03 | 1 | 2 | 15 | No | **Rejected** | Failed capacity gate at arrival - no seat, regardless of CPU/memory |
| REQ_04 | 1 | 3 | 25 | Yes | **Executed → Completed** | Capacity OK; 25 ≤ 50 free at t=2 |
| REQ_05 | 2 | 5 | 40 | Yes | **Waited → Rejected** | Capacity OK, but never saw ≥40 free within 3 retries (max free was 35) |
| REQ_06 | 2 | 1 | 10 | Yes | **Executed → Completed** | Capacity OK; small footprint fits alongside others |
| REQ_07 | 3 | 4 | 35 | Yes | **Executed → Completed** | Capacity OK; admitted once REQ_01 completed and freed memory |
| REQ_08 | 3 | 2 | 20 | No | **Rejected** | Failed capacity gate at arrival |
| REQ_11 (personalised) | 4 | 3 | 90 | Yes | **Waited → Rejected** | Capacity OK, but 90-unit demand never satisfiable against a 100-unit pool while smaller requests are resident |

## 5. Scheduling Strategy Selection and Justification

We selected **Round Robin (CPU) + bounded-retry Admission Control
(memory) + fail-fast gate (capacity)** over the alternatives:

- **First-Come-First-Served (FCFS)** was rejected because a single
  long CPU burst (e.g. REQ_02's 6 units) would block every request
  behind it for its full duration - unacceptable for "avoid blocking
  short requests unnecessarily."
- **Shortest-Job-First (SJF)** was rejected because it requires
  knowing burst time in advance and can starve long-running but
  legitimate requests (e.g. full timetable validation) indefinitely
  under continuous short-job arrivals - a fairness problem opposite to
  REQ_11's memory-starvation problem, but no less serious.
- **Priority scheduling** was considered but rejected for this stage,
  because the brief does not define a legitimate priority ordering
  between enrolment types, and introducing one without justification
  risks producing outcomes that look arbitrary rather than fair.

Round Robin was chosen because it guarantees **responsiveness**
(bounded wait for CPU) and **fairness** (no starvation on the CPU
dimension) without needing advance knowledge of burst times. Bounded-
retry admission control on memory was added specifically because Round
Robin alone says nothing about memory - our simulation shows that a
memory-heavy request can still fail even under a perfectly fair CPU
scheduler, which is why **both** constraints must be reasoned about
together, not in isolation (Rubric Criterion #4).

## 6. Team Coordination

This project was completed collaboratively by Jenish Gurung (s8210611)
and Hoang Gia Phat Nguyen (s8174754), Group 6. Regular check-ins were
used to divide work, agree on the scheduling design before
implementation began, and cross-check the final artefacts against each
other's sections. Full dated meeting minutes are provided in
`evidence/meeting_minutes_s8210611.txt`, and a summary of individual
contributions is provided in the written report and below:

| Student | Primary contribution |
|---|---|
| Jenish Gurung (s8210611) | System design, shell script implementation, execution log / process snapshot / failure case evidence generation, Sections 1-3 and Section A/C of the report |
| Hoang Gia Phat Nguyen (s8174754) | Scheduling strategy comparison and justification (Section B), trade-off analysis, reflection (Section D), report formatting and review |

## 7. Personalisation

Request `REQ_11` uses the last two digits of Student ID **s8210611**
("11"), satisfying the mandatory individualisation requirement. It is
also the request used throughout the failure analysis and reflection.
