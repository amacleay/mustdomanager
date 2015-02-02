use strict;
use warnings;

use Test::More;

require_ok('MustDoManager::Client');

#####################################
# task_manager_action

my $command = 'add hang the laundry';

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

foreach my $undefined_command (
  'add',
  'addition and subtraction',
  'hang yo mama out to dry',
  'completely engrossed',
  'complete',
  'complete me',
) {
  my ($manager_method, @manager_action) = MustDoManager::Client::task_manager_action($undefined_command);
  my $expect_method = 'help';
  is(
    $manager_method,
    $expect_method,
    "Undefined command gets right method '$expect_method': '$command'",
  );
}

done_testing();

