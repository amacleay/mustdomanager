use strict;
use warnings;

use Test::More;
use MustDoManager::TaskManager;

require_ok('MustDoManager::Client');

#####################################
# task_manager_action

my $date = MustDoManager::TaskManager::init_today();
foreach (
  ['add hang the laundry',
    'add_task',
    { description => 'hang the laundry' },
  ],
  ['add add some paper to the printer',
    'add_task',
    { description => 'add some paper to the printer' },
  ],
  ['complete 1',
    'complete_task',
    1,
  ],
  ['list',
    'task_list'
  ],
  ['',
    'help'
  ],
  ['remove 666',
    'remove_task',
    666,
  ],
  ['20010101 add walk the dog',
    'add_task',
    { description => 'walk the dog' },
    '20010101',
  ],
  ['tomorrow add walk the dog',
    'add_task',
    { description => 'walk the dog' },
    $date + 1,
  ],
  ['today complete 20',
    'complete_task',
    20,
    $date,
  ],
  ['yesterday list',
    'task_list',
    $date - 1,
  ],
  ['January 20, 1944 remove 30',
    'remove_task',
    30,
    '19440120',
  ],
) {
  my ($command, $expect_method, @expect_args) = @$_;
  my ($manager_method, @manager_args) = MustDoManager::Client::task_manager_action($command);
  is(
    $manager_method,
    $expect_method,
    "Gets correct method '$expect_method': '$command'",
  );
  is_deeply(
    \@manager_args,
    \@expect_args,
    "Arguments are correct: '$command'",
  );
}

my $expect_method = 'help';
foreach my $undefined_command (
  'add',
  'addition and subtraction',
  'hang yo mama out to dry',
  'completely engrossed',
  'complete',
  'complete me',
) {
  my ($manager_method, @manager_action) = MustDoManager::Client::task_manager_action($undefined_command);
  is(
    $manager_method,
    $expect_method,
    "Undefined command gets right method '$expect_method': '$undefined_command'",
  );
}

done_testing();

