import '../ui/tokens.dart';

/// Default split tags, in the order they are offered.
final seedSplits = [
  ('Legs', SplitColors.legs),
  ('Push', SplitColors.push),
  ('Pull', SplitColors.pull),
  ('Upper', SplitColors.upper),
  ('Lower', SplitColors.lower),
  ('Full body', SplitColors.full),
  ('Arms', SplitColors.arms),
  ('Core', SplitColors.core),
  ('Cardio', SplitColors.cardio),
];

/// What the body map draws. 'Full body' has no region of its own: those
/// lifts colour the map through their secondary muscles only.
const muscles = [
  'Chest', 'Front delts', 'Side delts', 'Rear delts', 'Traps', 'Upper back', 'Lats',
  'Lower back', 'Biceps', 'Triceps', 'Forearms', 'Abs', 'Obliques', 'Glutes',
  'Abductors', 'Adductors', 'Quads', 'Hamstrings', 'Calves', 'Full body',
];

/// The picker filters by these, so 20 muscles stay one short row of chips.
const muscleGroups = <String, List<String>>{
  'Chest': ['Chest'],
  'Shoulders': ['Front delts', 'Side delts', 'Rear delts'],
  'Back': ['Traps', 'Upper back', 'Lats', 'Lower back'],
  'Arms': ['Biceps', 'Triceps', 'Forearms'],
  'Core': ['Abs', 'Obliques'],
  'Legs': ['Glutes', 'Abductors', 'Adductors', 'Quads', 'Hamstrings', 'Calves'],
  'Full body': ['Full body'],
};

String groupOf(String muscle) =>
    muscleGroups.entries.where((g) => g.value.contains(muscle)).firstOrNull?.key ?? 'Full body';

/// Schema v2 muscles that v3 split up, for custom exercises the seed list
/// does not know by name.
const legacyMuscles = {'Shoulders': 'Front delts', 'Back': 'Upper back', 'Core': 'Abs'};

const equipments = [
  'Barbell', 'Dumbbell', 'Machine', 'Cable', 'Bodyweight', 'Kettlebell', 'Band', 'Other',
];

/// Default +/- step by equipment. Dumbbells go up in 2 kg pairs in most
/// gyms; machine stacks in 5.
double defaultIncrement(String equipment) => switch (equipment) {
      'Barbell' => 2.5,
      'Dumbbell' => 2,
      'Machine' => 5,
      'Cable' => 2.5,
      'Kettlebell' => 4,
      'Bodyweight' => 2.5,
      _ => 2.5,
    };

/// (name, muscle, equipment, kind, secondary muscles)
const seedExercises = <(String, String, String, String, List<String>)>[
  // Legs
  ('Back squat', 'Quads', 'Barbell', 'weightReps', ['Glutes', 'Adductors', 'Lower back']),
  ('Front squat', 'Quads', 'Barbell', 'weightReps', ['Glutes', 'Abs']),
  ('Hack squat', 'Quads', 'Machine', 'weightReps', ['Glutes']),
  ('Leg press', 'Quads', 'Machine', 'weightReps', ['Glutes', 'Adductors']),
  ('Goblet squat', 'Quads', 'Dumbbell', 'weightReps', ['Glutes', 'Abs']),
  ('Bulgarian split squat', 'Quads', 'Dumbbell', 'weightReps', ['Glutes', 'Adductors']),
  ('Walking lunge', 'Quads', 'Dumbbell', 'weightReps', ['Glutes', 'Hamstrings']),
  ('Leg extension', 'Quads', 'Machine', 'weightReps', []),
  ('Romanian deadlift', 'Hamstrings', 'Barbell', 'weightReps', ['Glutes', 'Lower back']),
  ('Deadlift', 'Hamstrings', 'Barbell', 'weightReps', ['Glutes', 'Lower back', 'Quads', 'Traps', 'Forearms']),
  ('Lying leg curl', 'Hamstrings', 'Machine', 'weightReps', ['Calves']),
  ('Seated leg curl', 'Hamstrings', 'Machine', 'weightReps', []),
  ('Good morning', 'Hamstrings', 'Barbell', 'weightReps', ['Lower back', 'Glutes']),
  ('Hip thrust', 'Glutes', 'Barbell', 'weightReps', ['Hamstrings']),
  ('Glute bridge', 'Glutes', 'Barbell', 'weightReps', ['Hamstrings']),
  ('Cable kickback', 'Glutes', 'Cable', 'weightReps', []),
  ('Hip abduction', 'Abductors', 'Machine', 'weightReps', ['Glutes']),
  ('Hip adduction', 'Adductors', 'Machine', 'weightReps', []),
  ('Step-up', 'Glutes', 'Dumbbell', 'weightReps', ['Quads']),
  ('Standing calf raise', 'Calves', 'Machine', 'weightReps', []),
  ('Seated calf raise', 'Calves', 'Machine', 'weightReps', []),
  // Chest
  ('Bench press', 'Chest', 'Barbell', 'weightReps', ['Triceps', 'Front delts']),
  ('Incline bench press', 'Chest', 'Barbell', 'weightReps', ['Front delts', 'Triceps']),
  ('Dumbbell bench press', 'Chest', 'Dumbbell', 'weightReps', ['Triceps', 'Front delts']),
  ('Incline dumbbell press', 'Chest', 'Dumbbell', 'weightReps', ['Front delts', 'Triceps']),
  ('Machine chest press', 'Chest', 'Machine', 'weightReps', ['Triceps', 'Front delts']),
  ('Cable fly', 'Chest', 'Cable', 'weightReps', ['Front delts']),
  ('Pec deck', 'Chest', 'Machine', 'weightReps', []),
  ('Push-up', 'Chest', 'Bodyweight', 'bodyweight', ['Triceps', 'Front delts', 'Abs']),
  ('Dip', 'Chest', 'Bodyweight', 'bodyweight', ['Triceps', 'Front delts']),
  // Back
  ('Pull-up', 'Lats', 'Bodyweight', 'bodyweight', ['Biceps', 'Upper back']),
  ('Chin-up', 'Lats', 'Bodyweight', 'bodyweight', ['Biceps']),
  ('Lat pulldown', 'Lats', 'Cable', 'weightReps', ['Biceps', 'Upper back']),
  ('Barbell row', 'Upper back', 'Barbell', 'weightReps', ['Lats', 'Rear delts', 'Biceps', 'Lower back']),
  ('Dumbbell row', 'Lats', 'Dumbbell', 'weightReps', ['Upper back', 'Rear delts', 'Biceps']),
  ('Seated cable row', 'Upper back', 'Cable', 'weightReps', ['Lats', 'Rear delts', 'Biceps']),
  ('Chest-supported row', 'Upper back', 'Machine', 'weightReps', ['Lats', 'Rear delts', 'Biceps']),
  ('T-bar row', 'Upper back', 'Barbell', 'weightReps', ['Lats', 'Biceps', 'Lower back']),
  ('Straight-arm pulldown', 'Lats', 'Cable', 'weightReps', []),
  ('Back extension', 'Lower back', 'Bodyweight', 'bodyweight', ['Glutes', 'Hamstrings']),
  ('Shrug', 'Traps', 'Dumbbell', 'weightReps', ['Forearms']),
  // Shoulders
  ('Overhead press', 'Front delts', 'Barbell', 'weightReps', ['Side delts', 'Triceps', 'Traps']),
  ('Dumbbell shoulder press', 'Front delts', 'Dumbbell', 'weightReps', ['Side delts', 'Triceps']),
  ('Machine shoulder press', 'Front delts', 'Machine', 'weightReps', ['Side delts', 'Triceps']),
  ('Lateral raise', 'Side delts', 'Dumbbell', 'weightReps', ['Traps']),
  ('Cable lateral raise', 'Side delts', 'Cable', 'weightReps', []),
  ('Rear delt fly', 'Rear delts', 'Dumbbell', 'weightReps', ['Upper back']),
  ('Reverse pec deck', 'Rear delts', 'Machine', 'weightReps', ['Upper back']),
  ('Face pull', 'Rear delts', 'Cable', 'weightReps', ['Upper back', 'Traps']),
  ('Arnold press', 'Front delts', 'Dumbbell', 'weightReps', ['Side delts', 'Triceps']),
  // Arms
  ('Barbell curl', 'Biceps', 'Barbell', 'weightReps', ['Forearms']),
  ('Dumbbell curl', 'Biceps', 'Dumbbell', 'weightReps', ['Forearms']),
  ('Hammer curl', 'Biceps', 'Dumbbell', 'weightReps', ['Forearms']),
  ('Incline dumbbell curl', 'Biceps', 'Dumbbell', 'weightReps', []),
  ('Cable curl', 'Biceps', 'Cable', 'weightReps', []),
  ('Preacher curl', 'Biceps', 'Machine', 'weightReps', []),
  ('Triceps pushdown', 'Triceps', 'Cable', 'weightReps', []),
  ('Overhead triceps extension', 'Triceps', 'Cable', 'weightReps', []),
  ('Skull crusher', 'Triceps', 'Barbell', 'weightReps', []),
  ('Close-grip bench press', 'Triceps', 'Barbell', 'weightReps', ['Chest', 'Front delts']),
  ('Bench dip', 'Triceps', 'Bodyweight', 'bodyweight', ['Chest', 'Front delts']),
  ('Wrist curl', 'Forearms', 'Dumbbell', 'weightReps', []),
  ("Farmer's carry", 'Forearms', 'Dumbbell', 'weightReps', ['Traps', 'Abs', 'Obliques']),
  // Core
  ('Plank', 'Abs', 'Bodyweight', 'time', ['Obliques']),
  ('Side plank', 'Obliques', 'Bodyweight', 'time', ['Abs']),
  ('Hanging leg raise', 'Abs', 'Bodyweight', 'reps', ['Obliques', 'Forearms']),
  ('Cable crunch', 'Abs', 'Cable', 'weightReps', []),
  ('Ab wheel rollout', 'Abs', 'Other', 'reps', ['Lats', 'Obliques']),
  ('Russian twist', 'Obliques', 'Dumbbell', 'weightReps', ['Abs']),
  ('Cable woodchop', 'Obliques', 'Cable', 'weightReps', ['Abs']),
  ('Dead bug', 'Abs', 'Bodyweight', 'reps', []),
  ('Pallof press', 'Obliques', 'Cable', 'weightReps', ['Abs']),
  ('Crunch', 'Abs', 'Bodyweight', 'reps', []),
  // Full body / conditioning
  ('Kettlebell swing', 'Glutes', 'Kettlebell', 'weightReps', ['Hamstrings', 'Lower back']),
  ('Clean and press', 'Full body', 'Barbell', 'weightReps', ['Quads', 'Glutes', 'Front delts', 'Traps', 'Triceps']),
  ('Power clean', 'Full body', 'Barbell', 'weightReps', ['Quads', 'Glutes', 'Hamstrings', 'Traps']),
  ('Thruster', 'Full body', 'Dumbbell', 'weightReps', ['Quads', 'Glutes', 'Front delts', 'Triceps']),
  ('Burpee', 'Full body', 'Bodyweight', 'reps', ['Chest', 'Quads', 'Abs']),
  ('Box jump', 'Full body', 'Bodyweight', 'reps', ['Quads', 'Glutes', 'Calves']),
  ('Sled push', 'Full body', 'Other', 'weightReps', ['Quads', 'Glutes', 'Calves']),
  ('Wall ball', 'Full body', 'Other', 'weightReps', ['Quads', 'Glutes', 'Front delts']),
  ('Turkish get-up', 'Full body', 'Kettlebell', 'weightReps', ['Abs', 'Obliques', 'Front delts', 'Glutes']),
];

/// One template in the starter plan: (split, name, [(exercise, sets, min, max, superset group)]).
typedef StarterItem = (String, int, int, int, int?);

const starterTemplates = <(String, String, List<StarterItem>)>[
  ('Legs', 'Leg day', [
    ('Back squat', 4, 6, 8, null),
    ('Romanian deadlift', 3, 8, 10, null),
    ('Leg press', 3, 10, 12, null),
    ('Walking lunge', 3, 10, 12, 1),
    ('Standing calf raise', 3, 12, 15, 1),
  ]),
  ('Push', 'Push day', [
    ('Bench press', 4, 6, 8, null),
    ('Overhead press', 3, 6, 8, null),
    ('Incline dumbbell press', 3, 8, 12, null),
    ('Lateral raise', 3, 12, 15, 1),
    ('Triceps pushdown', 3, 10, 12, 1),
  ]),
  ('Pull', 'Pull day', [
    ('Pull-up', 4, 6, 10, null),
    ('Barbell row', 4, 6, 8, null),
    ('Seated cable row', 3, 10, 12, null),
    ('Face pull', 3, 12, 15, 1),
    ('Dumbbell curl', 3, 10, 12, 1),
  ]),
  ('Upper', 'Upper day', [
    ('Incline bench press', 3, 6, 8, null),
    ('Lat pulldown', 3, 8, 10, null),
    ('Dumbbell shoulder press', 3, 8, 12, null),
    ('Chest-supported row', 3, 8, 12, null),
    ('Hammer curl', 3, 10, 12, 1),
    ('Overhead triceps extension', 3, 10, 12, 1),
  ]),
];

/// Mon Legs, Tue Push, Wed rest, Thu Pull, Fri Upper, Sat run, Sun rest.
const starterWeek = ['Leg day', 'Push day', null, 'Pull day', 'Upper day', 'cardio', null];

/// Minutes a workout takes: about 2.5 per working set with its rest, plus
/// five to warm up. 22 sets is an hour.
int workoutMinutes(int sets) => (sets * 2.5 + 5).round();

/// A ready-made workout for people who would rather not build their own.
typedef ReadyWorkout = ({String split, String name, String about, List<StarterItem> items});

/// About an hour each (20-23 working sets). Big lifts first, then pairs of
/// small ones as supersets to save time. Between them they cover all 19
/// muscles the body map draws, rear delts, calves and adductors included.
const readyWorkouts = <ReadyWorkout>[
  (
    split: 'Push',
    name: 'Push · chest',
    about: 'Chest, shoulders, triceps. Heavy press first, isolation pairs to finish.',
    items: [
      ('Bench press', 4, 6, 8, null),
      ('Incline dumbbell press', 3, 8, 10, null),
      ('Overhead press', 3, 6, 8, null),
      ('Cable fly', 3, 10, 12, 1),
      ('Lateral raise', 3, 12, 15, 1),
      ('Triceps pushdown', 3, 10, 12, 2),
      ('Overhead triceps extension', 3, 10, 12, 2),
    ],
  ),
  (
    split: 'Pull',
    name: 'Pull · back',
    about: 'Lats and upper back, rear delts and biceps. Vertical and horizontal pulls.',
    items: [
      ('Pull-up', 4, 6, 10, null),
      ('Barbell row', 4, 6, 8, null),
      ('Seated cable row', 3, 10, 12, null),
      ('Straight-arm pulldown', 2, 12, 15, null),
      ('Face pull', 3, 12, 15, 1),
      ('Hammer curl', 3, 10, 12, 1),
      ('Incline dumbbell curl', 3, 10, 12, null),
    ],
  ),
  (
    split: 'Legs',
    name: 'Legs · quads',
    about: 'Squat-led leg day with hamstrings, calves and abs so nothing is skipped.',
    items: [
      ('Back squat', 4, 6, 8, null),
      ('Romanian deadlift', 3, 8, 10, null),
      ('Leg press', 3, 10, 12, null),
      ('Leg extension', 3, 12, 15, 1),
      ('Lying leg curl', 3, 10, 12, 1),
      ('Standing calf raise', 4, 12, 15, 2),
      ('Hanging leg raise', 3, 10, 15, 2),
    ],
  ),
  (
    split: 'Lower',
    name: 'Lower · glutes',
    about: 'Glutes and hamstrings, plus the inner and outer thigh most plans leave out.',
    items: [
      ('Hip thrust', 4, 8, 10, null),
      ('Bulgarian split squat', 3, 8, 12, null),
      ('Romanian deadlift', 3, 8, 10, null),
      ('Seated leg curl', 3, 10, 12, 1),
      ('Hip abduction', 3, 12, 15, 1),
      ('Hip adduction', 3, 12, 15, 2),
      ('Seated calf raise', 3, 12, 15, 2),
    ],
  ),
  (
    split: 'Upper',
    name: 'Upper body',
    about: 'Chest, back, shoulders and arms in one hour. Pairs well with a lower day.',
    items: [
      ('Incline bench press', 3, 6, 8, null),
      ('Lat pulldown', 3, 8, 10, null),
      ('Dumbbell shoulder press', 3, 8, 10, null),
      ('Chest-supported row', 3, 8, 12, null),
      ('Lateral raise', 3, 12, 15, 1),
      ('Rear delt fly', 3, 12, 15, 1),
      ('Hammer curl', 2, 10, 12, 2),
      ('Triceps pushdown', 2, 10, 12, 2),
    ],
  ),
  (
    split: 'Full body',
    name: 'Full body A',
    about: 'Squat, bench, row. The whole body three times a week if you train less often.',
    items: [
      ('Back squat', 3, 6, 8, null),
      ('Bench press', 3, 6, 8, null),
      ('Barbell row', 3, 8, 10, null),
      ('Romanian deadlift', 3, 8, 10, null),
      ('Lateral raise', 3, 12, 15, 1),
      ('Face pull', 3, 12, 15, 1),
      ('Plank', 3, 1, 1, null),
    ],
  ),
  (
    split: 'Full body',
    name: 'Full body B',
    about: 'Deadlift, incline press, pulldown. Alternate with Full body A.',
    items: [
      ('Deadlift', 3, 4, 6, null),
      ('Incline dumbbell press', 3, 8, 10, null),
      ('Lat pulldown', 3, 8, 10, null),
      ('Walking lunge', 3, 10, 12, null),
      ('Arnold press', 3, 8, 10, null),
      ('Cable curl', 2, 10, 12, 1),
      ('Overhead triceps extension', 2, 10, 12, 1),
      ('Cable crunch', 3, 10, 15, null),
    ],
  ),
  (
    split: 'Arms',
    name: 'Arms & core',
    about: 'Biceps, triceps, forearms and abs. A fifth day, or when the big lifts need a rest.',
    items: [
      ('Close-grip bench press', 3, 6, 8, null),
      ('Chin-up', 3, 6, 10, null),
      ('Barbell curl', 3, 8, 10, 1),
      ('Skull crusher', 3, 8, 10, 1),
      ('Incline dumbbell curl', 3, 10, 12, 2),
      ('Triceps pushdown', 3, 10, 12, 2),
      ('Wrist curl', 2, 12, 15, null),
      ('Cable woodchop', 3, 10, 12, null),
    ],
  ),
];

/// A ready week: Monday first, each day a ready workout's name, 'cardio' or
/// null for rest.
typedef ReadyPlan = ({String name, String about, List<String?> week});

const readyPlans = <ReadyPlan>[
  (
    name: 'Full body 3×',
    about: 'Three hours a week. The best start if you are new or busy.',
    week: ['Full body A', null, 'Full body B', null, 'Full body A', 'cardio', null],
  ),
  (
    name: 'Upper / Lower 4×',
    about: 'Each muscle twice a week, two rest days in the middle.',
    week: ['Upper body', 'Legs · quads', null, 'Upper body', 'Lower · glutes', 'cardio', null],
  ),
  (
    name: 'Push / Pull / Legs 5×',
    about: 'Most volume. For people who already train regularly.',
    week: ['Push · chest', 'Pull · back', 'Legs · quads', null, 'Upper body', 'Lower · glutes', null],
  ),
];
