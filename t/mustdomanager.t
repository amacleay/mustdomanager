use strict;
use warnings;

use constant CONFIG_FILE => '/tmp/mustdomanager_t.yml';

use Test::More;
use Test::Exception;

use List::AllUtils qw(
any
all
none
);

require_ok('MustDoManager::TaskManager');

my $manager = MustDoManager::TaskManager->new(
  config_file => CONFIG_FILE,
);
isa_ok($manager, 'MustDoManager::TaskManager');

# Clear out any existing task list data:
# this is just for test idempotency
$manager->full_task_list({});
is_deeply(
  $manager->full_task_list(),
  {},
  join(' ',
    "Test precondition: full task list is empty.",
    "If this fails, then some assumptions made",
    "in the construction of some upcoming tests",
    "were invalid",
  ),
);

ok( $manager->config_file(), "Has a config file by default");

is(
  $manager->add_task({
      description => 'do the laundry',
    }),
  1,
  "Return value for add_task is 1"
);

is(
  $manager->task_list->[0]->{description},
  "do the laundry",
  "Task list item description is what it should be"
);

is(
  $manager->task_list->[0]->{ordinal},
  1,
  "First task has ordinal 1"
);

is(
  $manager->add_task({
      description => 'turn out the lights',
    }),
  2,
  "Return value of add_task for second task is 2 (ordinal)",
);
is(scalar @{ $manager->task_list }, 2, "Has two items");
is(
  $manager->task_list->[1]->{ordinal},
  2,
  "Second task has ordinal 1"
);

undef $manager;
$manager = MustDoManager::TaskManager->new(
  config_file => CONFIG_FILE,
);
is(scalar @{ $manager->task_list }, 2, "After reinstantiating, still have two items");

my $task_to_complete = $manager->task_list->[-1]->{ordinal};
$manager->complete_task($task_to_complete);

ok($manager->task_list->[-1]->{completed}, "Completing task marks it");
ok(!$manager->task_list->[0]->{completed}, "Completing a task doesn't side effect an other task");

$manager->add_task({
    description => 'wash the dog',
  });
is(scalar @{ $manager->task_list }, 3, "Has three items");
is($manager->task_list->[-1]->{ordinal}, 3, 'Right ordinal');
is($manager->task_list->[-1]->{description}, 'wash the dog', 'Right description');

###############
# Other dates
$manager->date($manager->date + 1);
is(scalar @{ $manager->task_list }, 0, "Task list is empty: new date");
$manager->add_task({
    description => 'pay off the mob',
  });
is(scalar @{ $manager->task_list }, 1, "Has just one item");
is($manager->task_list->[-1]->{ordinal}, 1, 'Right ordinal');
is($manager->task_list->[-1]->{description}, 'pay off the mob', 'Right description');

dies_ok(
  sub { $manager->date('not a date') },
  "Not able to change date to an invalid date",
);


###############
# Original date
$manager->date($manager->date - 1);
is(scalar @{ $manager->task_list }, 3, "When changing back to the original date, all of the original items are still present");
ok($manager->task_list->[1]->{completed}, "Completed task from original date is still completed");
is(
  $manager->task_list->[0]->{description},
  "do the laundry",
  "Original task still has correct description"
);

##################
# Task removal
my $original_task_list_size = @{ $manager->task_list };
my $task_to_remove = $manager->task_list->[1]->{ordinal};
is(
  $manager->remove_task($task_to_remove),
  $task_to_remove,
  "Return value of remove is the ordinal, indicating success",
);
ok(
  (none { $_->{ordinal} == $task_to_remove } @{ $manager->task_list }),
  "Task is indeed removed: ordinal is not in task list",
);
is(
  scalar @{ $manager->task_list },
  $original_task_list_size - 1,
  "Task list is one smaller",
);

my $highest_ordinal = $manager->task_list->[-1]->{ordinal};
is(
  $manager->remove_task($highest_ordinal),
  $highest_ordinal,
  "Able to remove last element from task list",
);

TODO: {
  local $TODO = join(' ',
    "This was a little complex to implement,",
    "especially given the fact that",
    "these objects should behave",,
    "reliably even when the process",
    "is shut down and restarted,",
    "so for now it's fine that we're",
    "a little 'forgetful' wrt ordinals",
  );

  ok(
    $manager->add_task({ description => 'moot' })
      > $highest_ordinal,
    "highest ordinal not reused, and new higher ordinal is assigned to new task",
  );
}

####################################
# Test variable date behavior

my $different_date = $manager->date - 15;
my $bogus_date = '12';  # obviously not a date

dies_ok { $manager->task_list( $bogus_date ) } "List dies with bogus date";

is_deeply(
  $manager->task_list( $different_date ),
  [],
  "Task list for an arbitrary new day is empty",
);

dies_ok { $manager->add_task({}, $bogus_date) } "Add dies with bogus date";
is(
  $manager->add_task(
    { description => 'feed the hogs' },
    $different_date,
  ),
  1,
  "Task is first task for new day",
);
is(
  $manager->task_list( $different_date )->[0]->{description},
  'feed the hogs',
  "Task description correct for new day",
);
ok(
  ! $manager->task_list( $different_date )->[0]->{completed},
  "Test precondition: brand new task not yet completed",
);

dies_ok { $manager->complete_task(1, $bogus_date) } "complete dies with bogus date";
$manager->complete_task(1, $different_date);
ok(
  $manager->task_list( $different_date )->[0]->{completed},
  "Able to complete task for different date",
);

dies_ok { $manager->remove_task(1, $bogus_date) } "remove dies with bogus date";
$manager->remove_task(1, $different_date);
is_deeply(
  $manager->task_list( $different_date ),
  [],
  "Able to successfully clear task list for different date",
);

done_testing;

