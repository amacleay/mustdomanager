package MustDoManager::TaskManager;

use strict;
use warnings;

use Carp;
use Moo;
use YAML;
use File::Spec;
use POSIX qw(
  strftime
);
use List::Util qw(
  max
);

has config_file => (
  is => 'ro',
  default => sub {
    (my $package_string = __PACKAGE__) =~ s/::/_/g ;
    return File::Spec->catfile(
      $ENV{HOME},
      "$package_string.yml",
    );
  },
);

has full_task_list => (
  isa => sub { confess "Must be hashref" unless ref $_[0] eq 'HASH' },
  is => 'rw',
  default => sub { return {} },
);
has date => (
  is => 'rw',
  isa => \&validate_date,
  default => \&init_today,
);
has today => (
  is => 'ro',
  isa => \&validate_date,
  default => \&init_today,
);

sub BUILD {
  my ($self)= @_;

  $self->full_task_list( YAML::LoadFile($self->config_file) )
    if -f $self->config_file;
}
sub DESTROY {
  my ($self) = @_;
  $self->save_current_state;
}

sub save_current_state {
  my ($self) = @_;

  YAML::DumpFile($self->config_file, $self->full_task_list);
}

sub add_task {
  my ($self, $task) = @_;
  
  my $highest_ordinal = max map { $_->{ordinal} } @{ $self->task_list };
  $highest_ordinal ||= 0;

  $task->{ordinal} = $highest_ordinal + 1;
  push @{ $self->task_list }, $task;

  return $task->{ordinal};
}


sub task_list {
  my ($self) = @_;
  $self->full_task_list->{ $self->date } ||= [];

  return $self->full_task_list->{ $self->date };
}

sub complete_task {
  my ($self, $ordinal) = @_;

  foreach my $task (@{ $self->task_list }) {
    if ($task->{ordinal} == $ordinal) {
      $task->{completed} = 1;
      return $ordinal;
    }
  }

  return 0;
}

sub remove_task {
  my ($self, $ordinal) = @_;

  my $original_task_list = $self->task_list;
  my @final_task_list;
  foreach my $task (@$original_task_list) {
    if ($task->{ordinal} != $ordinal) {
      push @final_task_list, $task;
    }
  }
  
  my $made_change = scalar @final_task_list != scalar @$original_task_list;
  @$original_task_list = @final_task_list;

  return $made_change ? $ordinal : 0;
}

sub init_today {
  return strftime "%Y%m%d", localtime();
}

sub validate_date {
  my $date = shift;
  confess "Must be a date in YYYYMMDD format, received $date"
    unless $date =~ m/^
        \d{4}  # yyyy
        \d{2}  # mm
        \d{2}  # dd
      $/x;
}

1;

__END__

=head1 NAME

MustDoManager::TaskManager - tiny application to manage
daily to-do list

=head1 SYNOPSIS

  my $taskmanager = MustDoManager::TaskManager->new();
  $taskmanager->add_task({
    description => 'walk the dog',
  });
  $taskmanager->add_task({
    description => 'mow the kids',
  });

  $taskmanager->complete_task(2);
  $taskmanager->task_list;
  >>> [
  >>>  { ordinal => 1, description => 'walk the dog' },
  >>>  { ordinal => 2, description => 'mow the kids', completed => 1 },
  >>> ]

=head1 DESRIPTION

Simple task manager application.  Tell it
what tasks need to be completed, and it
will store these and be able to display information
about them.

Data persists across restarts with the use of a L</config_file>
in which the MustDoManager::TaskManager persists its to-do list data.

=head1 METHODS

=head2 Attribute Methods

All of the following are accessible
as parameters to C<< new >> or by the typical
getter/setter methods of the same name.

=over 4

=item B<config_file>

=over 4

A YAML file location.
On initalization, a MustDoManager::TaskManager instance
will read in a previous state from the file at
the location C<< config_file >>, and on object
destruction, it will save its state to this
file.

You can also force state to save to the
location in C<< config_file >> with the
L</save_current_state> method.

=back

=item B<date>

=over 4

A date in YYYYMMDD format.

An instance of C<< MustDoManager::TaskManager >> may
keep track of multiple days worth of
todo lists at any one time.  Change L</date>
to toggle between different days' lists.

=back

=back

=head2 Utility methods

=over 4

=item B<new>

=item B<save_current_state>

=over 4

Flushes the current list state out
to the L</config_file>

=back

=item B<add_task>

=over 4

Takes a single argument, which is
a hashref describing a task to do.

Always adds an C<< ordinal >> key to this
task, which becomes this task's external
identifier for other methods.

The return value is the task's ordinal.

=back

=item B<complete_task>

=over 4

Given an ordinal, marks the task as complete.

Returns the ordinal on success, 0 on failure.

=back

=item B<remove_task>

=over 4

Given an ordinal, actually removes the task
from the list.  The task list will shrink if
this is successful.  Ordinals will not be
changed, but this ordinal may be reused.

Returns the ordinal on success, 0 on failure.

=back

=item B<task_list>

=over 4

Returns a hashref of this instance's
day's tasks.

=back

=back


=cut
