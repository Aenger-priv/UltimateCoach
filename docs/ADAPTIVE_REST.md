# Adaptive rest suggestions

Enable **Settings → Rest timer → Adaptive rest suggestions**. After an eligible weighted set, the timer can highlight **Suggested +30 sec**. The programmed rest always starts at its usual duration. Tapping the button adds 30 seconds. The ordinary timer also accepts manual extensions.

## Decision and feedback

- A decision is eligible when another set remains for the same lift, a positive rest time is prescribed, and the logged load matches the positive target load. A hard-set signal is an effort rating of two or fewer reps in reserve, a result below the prescribed rep minimum, or fewer reps than the previous set at the same load. Deloads are excluded.
- Within the current cycle and lifting phase, the app pools comparable decisions across exercises. It keeps the rest after set one separate from rests after later sets. Starting another cycle starts fresh. A saved decision retains its assignment and offer probability.
- The reward is one when the next set reaches the target load and rep minimum and the recorded effort meets the prescribed reserve. If the rating is omitted, the weight and rep checks determine the outcome. The next set must be the next logged action on the same exercise, 10 seconds to 15 minutes later. An interrupted or missing follow-up contributes no reward observation. These cutoffs filter logging artifacts; the app does not measure when a lifter actually started the next set.
- The learning target is the effect of highlighting the option. Both accepted and ignored offers with a usable next set count. The backup records whether the timer was extended. Set corrections update the reward on the next calculation, and undo removes the undone observation.

## Estimator and exploration

This borrows the separation of per-action reward estimates, explicit exploration probabilities, and chosen-action feedback from the ContextualBandits workbench. The parameters below are application defaults.

In each context, estimate the target-hit rate separately for each action as **(hits + 1) / (observations + 2)**. This regularizes small samples toward 50%. Until there are at least four observed outcomes per action, the offer probability is 50%. After that, an estimated advantage strictly above 10 percentage points gives the offer an 85% chance. Otherwise its chance is 15%. This is epsilon-greedy selection with two actions and epsilon of 0.30 after cold start. The 10-point margin expresses a preference for fewer prompts when the estimated benefit is small. It is not a statistical significance threshold.

Draw a uniform number in [0, 1) and offer if it falls below the selected probability. In the examples below a fixed draw of 0.50 shows how the same draw produces different actions.

| Observed target hits | Offer probability | Timer at draw 0.50 |
| --- | ---: | --- |
| Only three usual-timer outcomes so far | 50% | Usual |
| Offered 3/4, usual 1/4 | 85% | Suggest +30 sec |
| Offered 1/4, usual 3/4 | 15% | Usual |
| Both 4/4, or both 0/4 | 15% | Usual |
| Offered 2/8, usual 1/8 (smoothed advantage exactly 10 points) | 15% | Usual |

## Validation

The policy tests check exact choices at exploration boundaries, contrasting early and later sets, missing effort ratings, failed load and rep targets, deloads, interleaved exercises, missing outcomes, and future-data exclusion. Integration tests cover the timer extension, undo and backup restore. The seeded simulation gives each policy the same synthetic opportunities and feeds the adaptive policy only the selected outcome. It compares adaptive prompting with always prompting and always using the usual timer. It exercises both deliberately opposing effects by set position and a world where prompting has zero effect. Actual benefit to a lifter requires prospective evidence.

### Synthetic outcomes

Each row uses 32 seeded histories of 96 eligible decisions, split evenly between early and later rests. All counts are next-set target hits out of 3,072 opportunities. The conditional success probabilities are inputs chosen to test the algorithm.

| Simulated effect of highlighting the timer | Adaptive | Always highlight | Ordinary timer |
| --- | ---: | ---: | ---: |
| Helps later sets, hurts early sets (80% versus 20%, reversed by context) | 2,055 | 1,535 | 1,543 |
| Helps early sets, hurts later sets | 2,035 | 1,543 | 1,535 |
| Always helpful (80% versus 20%) | 2,021 | 2,474 | 604 |
| Always harmful (20% versus 80%) | 2,069 | 604 | 2,474 |
| No effect (50% either way) | 1,555 | 1,555 | 1,555 |
| Small benefit (55% versus 50%) | 1,622 | 1,721 | 1,555 |

In the late-benefit scenario, the policy highlighted 328 of 1,536 early rests and 1,198 of 1,536 later rests. The fixed policies did better when a single action was uniformly optimal. Exploration and the initial learning period cost outcomes in those cases. In the zero-effect scenario the simulator deliberately gives both actions the same outcome on each opportunity, so all three scores must agree. Real usage may yield much less information, especially when users skip logging a follow-up set.
