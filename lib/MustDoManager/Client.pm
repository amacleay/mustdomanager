package MustDoManager::Client;

use strict;
use warnings;

use Carp;
use English qw( -no_match_vars );
use File::Which qw( which );
use IPC::Run3 qw( run3 );
use MustDoManager::TaskManager;
use Readonly;
use Scalar::Util qw( looks_like_number );

Readonly::Hash my %action_dispatch => {
  add => sub {
    my ($description, @rest) = @_;

    if (
      !$description
      || $description =~ /^\s*$/
    ) {
      # no description, don't do it
      return;
    }
    else {
      return 'add_task', { description => $description }, @rest;
    }
  },
  complete => sub {
    my ($maybe_ordinal, @rest) = @_;
    if (looks_like_number $maybe_ordinal) {
      return 'complete_task', $maybe_ordinal, @rest;
    }
    else {
      return;
    }
  },
  remove => sub {
    my ($maybe_ordinal, @rest) = @_;
    if (looks_like_number $maybe_ordinal) {
      return 'remove_task', $maybe_ordinal, @rest;
    }
    else {
      return;
    }
  },
  list => sub {
    my (@rest) = @_;
    return 'task_list', @rest;
  },
  default => sub {
    return 'help';
  },
};
Readonly::Hash my %response_dispatch => {
  # The responses for add, complete, remove are basically identical
  (map {
    my $action = $_;
    (
      "${action}_task" => sub {
          my ($maybe_ordinal) = @_;

          if (looks_like_number $maybe_ordinal) {
            if ($maybe_ordinal > 0) {
              return sprintf 'Task %s succeeded: task #%d', $action, $maybe_ordinal;
            }
            else {
              return sprintf 'Task %s failed with code %d', $action, $maybe_ordinal;
            }
          }
          else {
            return "Failed to parse output";
          }
      },
    );
  } qw( add complete remove )),

  # The response for the rest are different
  task_list => sub {
    my ($task_list) = @_;
    my @task_lines = map {
      sprintf q{#%d: %s"%s"},
        $_->{ordinal},
        $_->{completed} ? "COMPLETE " : "",
        $_->{description},
    } @$task_list;
    my $header_line = "Task list:";
    return join "\n", $header_line, @task_lines;
  },
  help => sub {
    return <<EOH
MustDoManager.
Give me a command like 'add [description]', 'complete [number]', or 'list'
EOH
  },
};
Readonly my $action_keyword_regex => join("|",
  map { quotemeta } keys %action_dispatch,
);

sub process_cli_command {
  my $command = join " ",  @_;
  return process_command( $command ) . "\n";
}

sub process_command {
  my ($command, $task_manager) = @_;
  $task_manager ||= MustDoManager::TaskManager->new;

  my ( $manager_method, @manager_args )
    = task_manager_action($command);

  my @manager_response
    = response_from_command( $task_manager, $manager_method, @manager_args );

  return response_interpretation( $manager_method, @manager_response );
}

sub response_from_command {
  my ( $task_manager, $manager_method, @manager_args ) = @_;

  # 'help' is actually handled by the client
  if ($manager_method eq 'help') {
    return;
  }
  else {
    my @response = $task_manager->$manager_method( @manager_args );

    # Always save the state after the manager does something.
    # This is sort of a hack, but prevents having to be
    # concerned with a task getting lost.
    $task_manager->save_current_state;

    return @response;
  }
}

sub task_manager_action {
  my $command = shift;

  my @method_and_args;
  if ($command =~ /^(.*?)($action_keyword_regex)\b(.*)\s*/g) {
    my ($maybe_date, $command_keyword, $subcommand) = ($1, $2, $3);
    foreach ($maybe_date, $subcommand) {
      s/^\s*//;
      s/\s*$//;
    }

    my @args_for_action;
    if ($subcommand) {
      push @args_for_action, $subcommand;
    }
    if ($maybe_date) {
      my $date = translate_date($maybe_date);
      push @args_for_action, $date;
    }

    @method_and_args = $action_dispatch{$command_keyword}->(@args_for_action);
  }

  if (@method_and_args) {
    return @method_and_args;
  }
  else {
    return $action_dispatch{default}->();
  }
}

# For date parsing, we'll use GNU date,
# which has an awesome feature where it can
# parse "human readable" date strings
our $GNU_DATE
  = $OSNAME eq 'darwin' ? 'gdate'
  : $OSNAME eq 'linux' ? 'date'
  : undef;
our $CAN_GNU_DATE
  = which($GNU_DATE) ? 1
  : 0;

sub translate_date {
  my $date_string = shift;
  if ($CAN_GNU_DATE) {
    run3(
      [ $GNU_DATE, '-d', $date_string, '+%Y%m%d' ],
      undef,
      \(my $stdout),
      \(my $stderr)
    );
    chomp $stdout;

    return $stdout;
  }
  else {
    confess "Unable to parse dates: GNU date not available";
  }
}

sub response_interpretation {
  my ($method, @manager_response) = @_;

  if (my $responder = $response_dispatch{$method}) {
    return $responder->(@manager_response);
  }
  else {
    return "I did not understand your command\n" . response_interpretation('help');
  }
}

1;

__END__

=head1 NAME

MustDoManager::Client - client for a tiny
application to manage a daily to-do list

=head1 SYNOPSIS

 > mustdomanager add walk the dog
 >>> Added task 1
 > mustdomanager list
 >>> #1 walk the dog

=head1 DESCRIPTION

The purpose of this module is to provide a simple text-based
interface to a L<MustDoManager::TaskManager> object.

=cut
