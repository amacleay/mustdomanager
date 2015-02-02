package MustDoManager::Client;

use strict;
use warnings;

use MustDoManager::TaskManager;
use Readonly;
use Scalar::Util qw(
looks_like_number
);

Readonly::Hash my %action_dispatch => {
  add => sub {
    my ($description) = @_;

    if ($description =~ /^\s*$/) {
      # no description, don't do it
      return;
    }
    else {
      return 'add_task', { description => $description };
    }
  },
  complete => sub {
    my ($maybe_ordinal) = @_;
    if (looks_like_number $maybe_ordinal) {
      return 'complete_task', $maybe_ordinal;
    }
    else {
      return;
    }
  },
  default => sub {
    return 'help';
  },
  list => sub {
    return 'task_list';
  },
};
Readonly::Hash my %response_dispatch => {
  add_task => sub {
    my ($maybe_ordinal) = @_;

    if (looks_like_number $maybe_ordinal) {
      if ($maybe_ordinal > 0) {
        return sprintf "Added new task %d", $maybe_ordinal;
      }
      else {
        return sprintf "Task add failed with code %d", $maybe_ordinal;
      }
    }
    else {
      return "Failed to parse output";
    }
  },
  complete_task => sub {
    my ($maybe_ordinal) = @_;

    if (looks_like_number $maybe_ordinal) {
      if ($maybe_ordinal > 0) {
        return sprintf "Completed task %d", $maybe_ordinal;
      }
      else {
        return sprintf "Completion failed with code %d", $maybe_ordinal;
      }
    }
    else {
      return "Failed to parse output";
    }
  },
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
  if ($command =~ /^\s*($action_keyword_regex)\b/g) {
    my $command_keyword = $1;
    ( my $subcommand = $command ) =~ s/^\s*$command_keyword\s*//;
    @method_and_args = $action_dispatch{$command_keyword}->($subcommand);
  }

  if (@method_and_args) {
    return @method_and_args;
  }
  else {
    return $action_dispatch{default}->();
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
