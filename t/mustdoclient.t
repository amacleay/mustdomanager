use strict;
use warnings;

use Test::More;
use MustDoManager::TaskManager;
use DateTime;

require_ok('MustDoManager::Client');

my $date = today_datetime();

#####################################
# task_manager_action

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
    '',
  ],
  ['complete 5 with gusto',
    'complete_task',
    5,
    'with gusto',
  ],
  ['list',
    'task_list'
  ],
  ['',
    'help'
  ],
  ['date',
    'date',
  ],
  ['today date',
    'date',
    format_date($date),  # today's date
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
    format_date(
      $date->clone->add( days => 1 )
    ),
  ],
  ['today complete 20',
    'complete_task',
    20,
    '',
    format_date($date),
  ],
  ['1 week complete 17 we already figured it out',
    'complete_task',
    17,
    'we already figured it out',
    format_date(
      $date->clone->add( days => 7 )
    ),
  ],
  ['yesterday list',
    'task_list',
    format_date(
      $date->clone->subtract( days => 1 )
    ),
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
  'tomorrow add',
) {
  my ($manager_method, @manager_action) = MustDoManager::Client::task_manager_action($undefined_command);
  is(
    $manager_method,
    $expect_method,
    "Undefined command gets right method '$expect_method': '$undefined_command'",
  );
}

done_testing();

sub today_datetime {
  my $today_yyyymmdd = MustDoManager::TaskManager::init_today();
  # Date format is YYYYMMDD: parse it out so we can safely manipulate
  my ($year, $month, $day) = ( $today_yyyymmdd =~ /(\d{4})(\d{2})(\d{2})/ );
  $date = DateTime->new( year => $year, month => $month, day => $day );
}

sub format_date {
  my ($datetime_object) = @_;
  return $datetime_object->date('');
}
