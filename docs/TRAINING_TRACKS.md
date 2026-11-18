# Training tracks and cycle design

UltimateCoach offers two four-day upper/lower tracks. Each has 12 weeks of training followed by one week of reduced training demand. The exercise list repeats inside each track. Recorded performance can change the next target for the same exercise and weekly slot. Users select their track before creating a cycle. At rollover, the opposite track is preselected and the user can choose either track.

## Evidence and design choices

- **Alternating emphases.** A 35-study meta-analysis found a small benefit of periodized resistance training for maximal strength when volume was matched. It found no clear hypertrophy advantage. Daily or weekly variation also appeared to favor maximal strength in trained lifters in that analysis. The latest ACSM position stand found heavier loading favored maximal strength, while periodization did not consistently improve outcomes across the entire literature. The app uses a 12-week planning interval and suggests alternating for users who want to train both qualities over time. The specific length, order, and sequence are product choices. [Moesgaard et al.](https://pubmed.ncbi.nlm.nih.gov/35044672/) · [ACSM 2026 position stand](https://pmc.ncbi.nlm.nih.gov/articles/PMC12965823/)
- **Weekly volume.** A 67-study meta-regression found that gains generally increased with weekly sets, with diminishing returns. Direct and indirect sets should be distinguished. The old plan gave substantial work to the upper body and one session to the lower body. The revised Hypertrophy track adds a second lower day and shifts volume toward quads and hamstrings. It prescribes about 11 direct chest and back sets each, 13 quad sets, and 11 hamstring sets per week by the template’s primary muscle labels. The counts are a programming convention. Compound exercises also train muscles beyond their primary label. [Pelland et al.](https://pubmed.ncbi.nlm.nih.gov/41343037/)
- **Deloads.** An international coaching consensus supports reducing training demand, especially set volume, and allowing the timing to vary. A small 2026 trial in untrained men found similar lower-body growth and strength endurance when two weeks used reduced volume and frequency. A different trial of a complete mid-program week off found no muscle growth benefit and favored continuous training for some strength outcomes. Week 13 here uses reduced training instead of a week off. The timing and exact reduction are app defaults, and the workouts can be skipped or moved. [Bell et al.](https://doi.org/10.1186/s40798-023-00633-0) · [Pancar et al.](https://www.nature.com/articles/s41598-026-40612-5) · [Coleman et al.](https://doi.org/10.7717/peerj.16777)

## Weekly prescriptions

| | Hypertrophy | Strength |
| --- | --- | --- |
| Schedule | Upper, lower, upper, lower on days 1, 2, 4, 6 | Same days |
| Main lifts | Mostly 6–12 reps | Bench and squat twice per week and deadlift once. Main work mostly 3–6 reps. |
| Assistance | Mostly 8–15 reps | Mostly 5–12 reps |
| Working sets | 68 per week, versus 60 in the original plan | 43 per week |
| Rest | 90–180 seconds | 90–240 seconds, with longer rests for the main lifts |
| Conditioning | Two easy rows | Two easy rows |
| Week 13 | 40 sets total, roughly half the sets per exercise rounded up | 26 sets total, same rule |

The deload uses the lower end of each rep range and starts at about 85% of the reference load, rounded down. The reference uses the lower of the planned and logged load when the latest full training exposure is available. Deload sets aim for four or more reps in reserve. There is no prescribed conditioning in Week 13, and deload logs do not drive progression or the next cycle's starting loads.

For the new tracks, topping the rep range on every set at the prescribed load with at least two reps in reserve can trigger a weight increase. A missing effort rating uses the track's default. A valid full session with reps below the minimum can count as a miss. Three consecutive misses can reduce the target. Easy sets inside the rep range retain the target. Explicit manual targets take precedence. These are deterministic app rules and do not depend on a percentage of tested 1RM.

A returning lifter gets an editable starting suggestion for matching weighted exercises with completed logs. It starts at no more than 90% of the most recent completed working weight, with a further reduction if the new rep range is higher. Seed weights for unfamiliar lifts are examples.

## Cycle state and records

A cycle advances from training to deload to ready for the next track based on the scheduled dates. Rescheduling can move the end date, and an active workout blocks rollover until it is closed. Creating a new cycle archives the old program and keeps its results in Progress. The app still opens original legacy schedules. At the end of a legacy schedule, its owner can add a recovery week or proceed to the new track chooser. The Program tab also has an **End program early** action. It archives the current cycle, closes an open session while retaining anything already logged, and opens the track chooser. You can close the chooser and restart later. A fresh start after ending early uses the new track's example loads for you to review. Backup format 4 continues to preserve an active cycle and archived cycles. Archive-only backups use format 5, and restore continues to accept earlier backup formats.

Rescheduling an individual workout changes only its date. It keeps its training week, day number, and targets, even if the new date places it after another workout. Use **Settings → Move upcoming workouts** to shift the remaining schedule together.

The expanded schema was checked against the original audit simulator store. It retained the 12-week legacy program and all 48 scheduled workouts. Tests also round-trip saved sets across both active and archived cycles through backup format 4.
