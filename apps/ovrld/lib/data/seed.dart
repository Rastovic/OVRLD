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

const muscles = [
  'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Chest', 'Back', 'Shoulders',
  'Biceps', 'Triceps', 'Forearms', 'Core', 'Full body',
];

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

/// (name, muscle, equipment, kind)
const seedExercises = [
  // Legs
  ('Back squat', 'Quads', 'Barbell', 'weightReps'),
  ('Front squat', 'Quads', 'Barbell', 'weightReps'),
  ('Hack squat', 'Quads', 'Machine', 'weightReps'),
  ('Leg press', 'Quads', 'Machine', 'weightReps'),
  ('Goblet squat', 'Quads', 'Dumbbell', 'weightReps'),
  ('Bulgarian split squat', 'Quads', 'Dumbbell', 'weightReps'),
  ('Walking lunge', 'Quads', 'Dumbbell', 'weightReps'),
  ('Leg extension', 'Quads', 'Machine', 'weightReps'),
  ('Romanian deadlift', 'Hamstrings', 'Barbell', 'weightReps'),
  ('Deadlift', 'Hamstrings', 'Barbell', 'weightReps'),
  ('Lying leg curl', 'Hamstrings', 'Machine', 'weightReps'),
  ('Seated leg curl', 'Hamstrings', 'Machine', 'weightReps'),
  ('Good morning', 'Hamstrings', 'Barbell', 'weightReps'),
  ('Hip thrust', 'Glutes', 'Barbell', 'weightReps'),
  ('Glute bridge', 'Glutes', 'Barbell', 'weightReps'),
  ('Cable kickback', 'Glutes', 'Cable', 'weightReps'),
  ('Hip abduction', 'Glutes', 'Machine', 'weightReps'),
  ('Step-up', 'Glutes', 'Dumbbell', 'weightReps'),
  ('Standing calf raise', 'Calves', 'Machine', 'weightReps'),
  ('Seated calf raise', 'Calves', 'Machine', 'weightReps'),
  // Chest
  ('Bench press', 'Chest', 'Barbell', 'weightReps'),
  ('Incline bench press', 'Chest', 'Barbell', 'weightReps'),
  ('Dumbbell bench press', 'Chest', 'Dumbbell', 'weightReps'),
  ('Incline dumbbell press', 'Chest', 'Dumbbell', 'weightReps'),
  ('Machine chest press', 'Chest', 'Machine', 'weightReps'),
  ('Cable fly', 'Chest', 'Cable', 'weightReps'),
  ('Pec deck', 'Chest', 'Machine', 'weightReps'),
  ('Push-up', 'Chest', 'Bodyweight', 'bodyweight'),
  ('Dip', 'Chest', 'Bodyweight', 'bodyweight'),
  // Back
  ('Pull-up', 'Back', 'Bodyweight', 'bodyweight'),
  ('Chin-up', 'Back', 'Bodyweight', 'bodyweight'),
  ('Lat pulldown', 'Back', 'Cable', 'weightReps'),
  ('Barbell row', 'Back', 'Barbell', 'weightReps'),
  ('Dumbbell row', 'Back', 'Dumbbell', 'weightReps'),
  ('Seated cable row', 'Back', 'Cable', 'weightReps'),
  ('Chest-supported row', 'Back', 'Machine', 'weightReps'),
  ('T-bar row', 'Back', 'Barbell', 'weightReps'),
  ('Straight-arm pulldown', 'Back', 'Cable', 'weightReps'),
  ('Back extension', 'Back', 'Bodyweight', 'bodyweight'),
  ('Shrug', 'Back', 'Dumbbell', 'weightReps'),
  // Shoulders
  ('Overhead press', 'Shoulders', 'Barbell', 'weightReps'),
  ('Dumbbell shoulder press', 'Shoulders', 'Dumbbell', 'weightReps'),
  ('Machine shoulder press', 'Shoulders', 'Machine', 'weightReps'),
  ('Lateral raise', 'Shoulders', 'Dumbbell', 'weightReps'),
  ('Cable lateral raise', 'Shoulders', 'Cable', 'weightReps'),
  ('Rear delt fly', 'Shoulders', 'Dumbbell', 'weightReps'),
  ('Face pull', 'Shoulders', 'Cable', 'weightReps'),
  ('Arnold press', 'Shoulders', 'Dumbbell', 'weightReps'),
  // Arms
  ('Barbell curl', 'Biceps', 'Barbell', 'weightReps'),
  ('Dumbbell curl', 'Biceps', 'Dumbbell', 'weightReps'),
  ('Hammer curl', 'Biceps', 'Dumbbell', 'weightReps'),
  ('Incline dumbbell curl', 'Biceps', 'Dumbbell', 'weightReps'),
  ('Cable curl', 'Biceps', 'Cable', 'weightReps'),
  ('Preacher curl', 'Biceps', 'Machine', 'weightReps'),
  ('Triceps pushdown', 'Triceps', 'Cable', 'weightReps'),
  ('Overhead triceps extension', 'Triceps', 'Cable', 'weightReps'),
  ('Skull crusher', 'Triceps', 'Barbell', 'weightReps'),
  ('Close-grip bench press', 'Triceps', 'Barbell', 'weightReps'),
  ('Bench dip', 'Triceps', 'Bodyweight', 'bodyweight'),
  ('Wrist curl', 'Forearms', 'Dumbbell', 'weightReps'),
  ("Farmer's carry", 'Forearms', 'Dumbbell', 'weightReps'),
  // Core
  ('Plank', 'Core', 'Bodyweight', 'time'),
  ('Side plank', 'Core', 'Bodyweight', 'time'),
  ('Hanging leg raise', 'Core', 'Bodyweight', 'reps'),
  ('Cable crunch', 'Core', 'Cable', 'weightReps'),
  ('Ab wheel rollout', 'Core', 'Other', 'reps'),
  ('Russian twist', 'Core', 'Dumbbell', 'weightReps'),
  ('Dead bug', 'Core', 'Bodyweight', 'reps'),
  ('Pallof press', 'Core', 'Cable', 'weightReps'),
  ('Crunch', 'Core', 'Bodyweight', 'reps'),
  // Full body / conditioning
  ('Kettlebell swing', 'Full body', 'Kettlebell', 'weightReps'),
  ('Clean and press', 'Full body', 'Barbell', 'weightReps'),
  ('Power clean', 'Full body', 'Barbell', 'weightReps'),
  ('Thruster', 'Full body', 'Dumbbell', 'weightReps'),
  ('Burpee', 'Full body', 'Bodyweight', 'reps'),
  ('Box jump', 'Full body', 'Bodyweight', 'reps'),
  ('Sled push', 'Full body', 'Other', 'weightReps'),
  ('Wall ball', 'Full body', 'Other', 'weightReps'),
  ('Turkish get-up', 'Full body', 'Kettlebell', 'weightReps'),
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
