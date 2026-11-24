# RowErg workout setup

In a planned or active workout, open **Conditioning → Set up RowErg**. For a prescription with a time range, pick the duration for this session. Wake the PM5, open **Connect**, tap **Find a PM5** in UltimateCoach and choose the number on your monitor. Allow Bluetooth when prompted. Check the workout on the monitor and row. Enter the result in Conditioning afterward.

The current strength and hypertrophy tracks prescribe easy timed rows. Older programs also contain distance intervals, Tabata, Zone 2 rows and a progressive timed row. A PM5 can receive time, distance, monitor Calories and finite repeat prescriptions with timed recoveries. For a finite interval session the app sends each effort and removes the rest after the last one. Pace and effort cues stay visible on the phone. Unrecognized prescriptions are shown in their original form for manual entry.

Bluetooth setup uses the PM5 control service on demand. It checks the monitor’s workout state, waits for the monitor to acknowledge each programming command and releases the connection at the end. The app does not read telemetry or write rowing results during setup. If confirmation is interrupted, inspect the monitor before retrying. [Concept2 development resources](https://www.concept2.com/support/software-development)

For ErgData, choose **Set up manually**, pair ErgData with the monitor and enter the displayed targets. ErgData can save a workout as a favorite and share its own workout links. Concept2 documents its Logbook API for completed results. I found no published interface for creating an arbitrary planned workout link in ErgData. [ErgData](https://www.concept2.com/ergdata) · [PM5 manual](https://www.concept2.com/support/monitors/pm5/how-to-use) · [Logbook API](https://log.concept2.com/developers/documentation/)

## Physical validation

Automated tests compare time, distance and Calorie messages against Concept2's reference examples and exercise finite interval counts, recoveries and response validation. A physical PM5 is required to check discovery, the permission prompt, an actual transfer, the displayed target after disconnect and real interval transitions. Suggested checks are a 20-minute row, six 500 m efforts with 90 seconds of rest, and eight 20-second efforts with 10 seconds of rest. Verify that a workout already underway on the monitor is preserved.
