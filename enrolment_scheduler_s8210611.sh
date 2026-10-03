#!/bin/bash
# Student Name: Jenish Gurung (s8210611) & Hoang Gia Phat Nguyen (s8174754)
# Student ID: s8210611
# Assessment: VU Enrolment System Scheduler
#
# -----------------------------------------------------------------------
# PURPOSE
# -----------------------------------------------------------------------
# This script simulates the VU online enrolment system as an operating
# system problem. Each enrolment request is modelled as a process that
# competes for two constrained resources:
#   1. CPU time     - processing capacity, shared via Round Robin (RR)
#   2. Memory       - session/record memory, a fixed shared pool
# A third, non-resource constraint (class seat capacity) is also
# enforced as an admission-control gate before a request is ever
# considered for memory or CPU.
#
# SCHEDULING STRATEGY: Round Robin with Admission Control
#   - Round Robin (fixed quantum) is used for CPU because it guarantees
#     that no single long-running validation (e.g. full timetable
#     re-check) can starve short requests (e.g. a seat check). This
#     directly satisfies the brief's requirement to "avoid blocking
#     short requests unnecessarily".
#   - Admission control on MEMORY models real multiprogramming: several
#     enrolment requests may legitimately be resident in memory
#     (holding a partially-processed student record) at once, but only
#     ONE of them is ever executing on the CPU at any instant, per the
#     assignment's system assumption. Memory is only released when a
#     request fully COMPLETES.
#   - Admission control on CAPACITY is checked once, at arrival, before
#     a request ever enters memory. If the class is full, the request
#     is rejected immediately - no amount of free CPU/memory can fix a
#     capacity problem, so it must fail fast ("prevent invalid
#     enrolments").
#
# PERSONALISATION
#   Request ID REQ_11 uses the last two digits of Student ID s8210611
#   (Jenish Gurung), i.e. "11", as required by the individualisation
#   rule. Its deliberately high memory demand (90/100 units) is used
#   later in failure_case_explanation_s8210611.txt.
# -----------------------------------------------------------------------

echo "========================================================================"
echo " VU ENROLMENT & TIMETABLE ALLOCATION SYSTEM - SCHEDULER SIMULATION"
echo " Student: Jenish Gurung | Student ID: s8210611"
echo " Student: Hoang Gia Phat Nguyen | Student ID: s8174754"
echo " Assessment: VU Enrolment System Scheduler"
echo " Generated: $(date)"
echo "========================================================================"
echo

# Brief system initialisation pause. This is not part of the scheduling
# algorithm - it exists purely so the running process can be observed
# with `ps`/`top` for the UNIX Observation evidence requirement, the
# same way a real service has measurable startup time before a health
# check can observe it.
sleep 2

# ---------------------------------------------------------------------
# SYSTEM CONFIGURATION (constraints)
# ---------------------------------------------------------------------
MEM_TOTAL=100          # total shared memory pool (units)
MEM_FREE=$MEM_TOTAL    # currently free memory
TIME_SLICE=2           # Round Robin CPU quantum (units)
MAX_WAIT_ROUNDS=3      # max admission retries before a memory reject
CURRENT_TIME=0

# ---------------------------------------------------------------------
# ENROLMENT REQUESTS (arrays = parallel "process table")
#   ID           arrival time, CPU burst, memory need, seat capacity flag
# ---------------------------------------------------------------------
IDS=(REQ_01 REQ_02 REQ_03 REQ_04 REQ_05 REQ_06 REQ_07 REQ_08 REQ_11)
ARRIVAL=(0 0 1 1 2 2 3 3 4)
CPU_BURST=(4 6 2 3 5 1 4 2 3)
MEM_NEED=(20 30 15 25 40 10 35 20 90)
CAP_FLAG=(1 1 0 1 1 1 1 0 1)     # 1 = seat available, 0 = class full
DESC=("Seat check" "Timetable validation" "Tutorial swap" "Prerequisite check" \
      "Full timetable validation" "Seat check" "Clash detection" "Tutorial swap" \
      "Prerequisite check (personalised: last 2 digits of s8210611)")

N=${#IDS[@]}
REMAINING=("${CPU_BURST[@]}")     # remaining CPU burst per request
STATUS=()                         # NEW / READY / WAITING / DONE / REJECTED
WAIT_COUNT=()
for ((i=0; i<N; i++)); do
    STATUS[$i]="NEW"
    WAIT_COUNT[$i]=0
done

ADMITTED=()      # queue of indices resident in memory, awaiting CPU (Round Robin)
PENDING=()       # queue of indices whose capacity passed, but memory not yet free
ARRIVED=()       # indices already announced as "arrived" (avoid duplicate logs)

ACCEPTED_COUNT=0
REJECTED_COUNT=0
COMPLETED_COUNT=0

log() { echo "[t=${CURRENT_TIME}] $1"; }

# ---------------------------------------------------------------------
# HELPER: check for new arrivals at/ before CURRENT_TIME and run
#         capacity admission control immediately.
# ---------------------------------------------------------------------
check_arrivals() {
    for ((i=0; i<N; i++)); do
        already_arrived=0
        for a in "${ARRIVED[@]}"; do
            [ "$a" == "$i" ] && already_arrived=1
        done
        if [ "$already_arrived" -eq 0 ] && [ "${ARRIVAL[$i]}" -le "$CURRENT_TIME" ]; then
            ARRIVED+=("$i")
            log "${IDS[$i]} ARRIVED  (${DESC[$i]}; cpu=${CPU_BURST[$i]}, mem=${MEM_NEED[$i]}, seat=${CAP_FLAG[$i]})"
            if [ "${CAP_FLAG[$i]}" -eq 0 ]; then
                STATUS[$i]="REJECTED"
                REJECTED_COUNT=$((REJECTED_COUNT+1))
                log "${IDS[$i]} REJECTED - class capacity full (seat constraint failed at admission gate)"
            else
                STATUS[$i]="PENDING_MEM"
                PENDING+=("$i")
                log "${IDS[$i]} PASSED capacity check -> queued for memory admission"
            fi
        fi
    done
}

# ---------------------------------------------------------------------
# HELPER: try to admit PENDING requests into memory (FIFO fairness)
# ---------------------------------------------------------------------
try_admit_pending() {
    NEW_PENDING=()
    for i in "${PENDING[@]}"; do
        if [ "${MEM_NEED[$i]}" -le "$MEM_FREE" ]; then
            MEM_FREE=$((MEM_FREE - MEM_NEED[$i]))
            STATUS[$i]="READY"
            ADMITTED+=("$i")
            ACCEPTED_COUNT=$((ACCEPTED_COUNT+1))
            log "${IDS[$i]} ADMITTED to memory (allocated ${MEM_NEED[$i]}; free memory now ${MEM_FREE}/${MEM_TOTAL}) -> entered Ready Queue"
        else
            WAIT_COUNT[$i]=$((WAIT_COUNT[$i]+1))
            if [ "${WAIT_COUNT[$i]}" -gt "$MAX_WAIT_ROUNDS" ]; then
                STATUS[$i]="REJECTED"
                REJECTED_COUNT=$((REJECTED_COUNT+1))
                log "${IDS[$i]} REJECTED - insufficient memory after ${MAX_WAIT_ROUNDS} admission retries (needs ${MEM_NEED[$i]}, only ${MEM_FREE}/${MEM_TOTAL} free)"
            else
                log "${IDS[$i]} WAITING - insufficient memory (needs ${MEM_NEED[$i]}, only ${MEM_FREE}/${MEM_TOTAL} free) [retry ${WAIT_COUNT[$i]}/${MAX_WAIT_ROUNDS}]"
                NEW_PENDING+=("$i")
            fi
        fi
    done
    PENDING=("${NEW_PENDING[@]}")
}

# ---------------------------------------------------------------------
# MAIN SIMULATION LOOP (Round Robin CPU + Memory Admission Control)
# ---------------------------------------------------------------------
SAFETY=0
while :; do
    SAFETY=$((SAFETY+1))
    [ "$SAFETY" -gt 200 ] && { log "SAFETY STOP - simulation exceeded 200 iterations"; break; }

    check_arrivals
    try_admit_pending

    # termination: nothing left to arrive, nothing pending, nothing ready
    all_future_arrived=1
    for ((i=0; i<N; i++)); do
        found=0
        for a in "${ARRIVED[@]}"; do [ "$a" == "$i" ] && found=1; done
        [ "$found" -eq 0 ] && all_future_arrived=0
    done
    if [ "$all_future_arrived" -eq 1 ] && [ "${#PENDING[@]}" -eq 0 ] && [ "${#ADMITTED[@]}" -eq 0 ]; then
        break
    fi

    if [ "${#ADMITTED[@]}" -eq 0 ]; then
        # CPU idle this tick: nothing ready to run, advance clock and retry admission
        CURRENT_TIME=$((CURRENT_TIME+1))
        continue
    fi

    # Round Robin dispatch: pop front of ready queue
    j=${ADMITTED[0]}
    ADMITTED=("${ADMITTED[@]:1}")
    STATUS[$j]="RUNNING"

    before=${REMAINING[$j]}
    if [ "$before" -le "$TIME_SLICE" ]; then
        run_time=$before
    else
        run_time=$TIME_SLICE
    fi
    REMAINING[$j]=$((before - run_time))
    start_t=$CURRENT_TIME
    CURRENT_TIME=$((CURRENT_TIME + run_time))

    if [ "${REMAINING[$j]}" -le 0 ]; then
        STATUS[$j]="DONE"
        COMPLETED_COUNT=$((COMPLETED_COUNT+1))
        MEM_FREE=$((MEM_FREE + MEM_NEED[$j]))
        log "${IDS[$j]} RAN [${start_t}-${CURRENT_TIME}] (remaining ${before}->0) -> COMPLETED. Memory released (+${MEM_NEED[$j]}); free memory now ${MEM_FREE}/${MEM_TOTAL}"
    else
        STATUS[$j]="READY"
        ADMITTED+=("$j")
        log "${IDS[$j]} RAN [${start_t}-${CURRENT_TIME}] (remaining ${before}->${REMAINING[$j]}) -> quantum expired, requeued (still resident in memory)"
    fi
done

echo
echo "========================================================================"
echo " EXECUTION SUMMARY @ t=${CURRENT_TIME}"
echo "========================================================================"
printf "%-8s %-9s %-12s\n" "ID" "Outcome" "Notes"
for ((i=0; i<N; i++)); do
    printf "%-8s %-9s %-12s\n" "${IDS[$i]}" "${STATUS[$i]}" "${DESC[$i]}"
done
echo
echo "Accepted (admitted to memory): ${ACCEPTED_COUNT}"
echo "Completed (finished execution): ${COMPLETED_COUNT}"
echo "Rejected (capacity or memory):  ${REJECTED_COUNT}"
echo "Total requests processed:       ${N}"
echo "========================================================================"
