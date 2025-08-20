package TVision::ViewLinks;

use strict;
use warnings;

our $VERSION = '0.02';

use Exporter 'import';
our @EXPORT_OK = qw(
  set_owner set_next set_last set_current
  get_owner get_next get_last get_current get_first 
  insert_after insert_first remove_view 
  children sanity_check
);

use Hash::Util::FieldHash qw(fieldhashes id register id_2obj);

# Per-object fields keyed by the wrapper objects.
fieldhashes \our (%OWNER, %NEXT, %LAST, %CURRENT);

#--- internals --------------------------------------------------------------
sub _reg { my ($o) = @_; register($o); return $o }
sub _id  { my ($o) = @_; return defined $o ? (_reg($o), id $o)[1] : undef }

#--- setters ----------------------------------------------------------------
sub set_owner   { my ($view,  $group) = @_; $OWNER{$view}    = _id($group) }
sub set_next    { my ($view,  $next ) = @_; $NEXT{$view}     = _id($next)  }
sub set_last    { my ($group, $last ) = @_; $LAST{$group}    = _id($last)  }
sub set_current { my ($group, $cur  ) = @_; $CURRENT{$group} = _id($cur)   }

#--- getters (ID -> object) -------------------------------------------------
sub get_owner   { my ($view)  = @_; my $i = $OWNER{$view};    return defined $i ? id_2obj($i) : undef }
sub get_next    { my ($view)  = @_; my $i = $NEXT{$view};     return defined $i ? id_2obj($i) : undef }
sub get_last    { my ($group) = @_; my $i = $LAST{$group};    return defined $i ? id_2obj($i) : undef }
sub get_current { my ($group) = @_; my $i = $CURRENT{$group}; return defined $i ? id_2obj($i) : undef }

#--- helpers ----------------------------------------------------------------
sub get_first {
    my ($group) = @_;
    my $last = get_last($group) or return undef;
    return get_next($last);
}

sub children {
    my ($group) = @_;
    my $first = get_first($group) or return ();
    my @out; my $v = $first;
    my $guard = 0; my $max = 10000; # safety
    do {
        push @out, $v;
        $v = get_next($v);
    } while defined($v) && $v != $first && ++$guard < $max;
    return @out;
}

# Insert $new after $target in group's ring. Update owner and last if needed.
sub insert_after {
    my ($group, $target, $new) = @_;
    die "insert_after: target belongs to different group"
        if get_owner($target) && get_owner($target) != $group;

    my $next = get_next($target) // $target;  # single-node ring or unlinked target
    set_next($new,   $next);
    set_next($target,$new);
    set_owner($new,  $group);
    if (defined(my $last = get_last($group))) {
        set_last($group, $new) if $target == $last;  # append
    } else {
        # group was empty; establish last
        set_last($group, $new);
    }
    return $new;
}

# Insert $new as first child of $group (keeps ring order semantics)
sub insert_first {
    my ($group, $new) = @_;
    if (my $last = get_last($group)) {
        insert_after($group, $last, $new);
    } else {
        set_next($new,   $new);   # single-node ring
        set_owner($new,  $group);
        set_last($group, $new);
    }
    return $new;
}

# Remove $view from group's ring. Returns true if removed.
sub remove_view {
    my ($group, $view) = @_;
    my $last = get_last($group) or return 0;          # empty group
    die "remove_view: node not in this group" 
        if get_owner($view) && get_owner($view) != $group;

    my $first = get_next($last);
    my $pred;
    my $v = $first;
    { 
        do {
            if (get_next($v) && get_next($v) == $view) { $pred = $v; last }
            $v = get_next($v);
        } while $v && $v != $first;
    }
    return 0 unless $pred;                           # not linked

    my $view_next = get_next($view);
    set_next($pred, $view_next);

    if ($view == $last) {
        if ($view_next == $view) {
            # was single element
            set_last($group, undef);
        } else {
            set_last($group, $pred);
        }
    }

    # detach
    set_owner($view, undef);
    set_next($view,  undef);
    return 1;
}

# Validate ring variants; return true on successful otherwise false and 
# issue a warning
sub sanity_check {
    my ($group) = @_;
    my $last = get_last($group);
    my $first = get_first($group);

    if (!$last) {
        if ( defined($first) ) { 
            warn 'first set but last undef'; 
            return
        }
        return !!1;    # empty is fine
    }

    unless ( $first ) {
        warn 'first undef although last is set';
        return
    }

    # Walk ring and collect
    my %seen; my @nodes;
    my $v = $first;
    my $guard = 0; my $max = 10000;
    do {
        unless ( get_owner($v) && get_owner($v) == $group ) {
            warn 'owner mismatch';
            return
        }
        my $k = id($v);
        if ( $seen{$k}++ ) {
            warn 'duplicate node in ring';
            return
        }
        push @nodes, $v;
        $v = get_next($v);
    } while defined($v) && $v != $first && ++$guard < $max;

    if ( $guard >= $max ) {
        warn 'ring not closed or too long';
        return
    }
    unless ( grep { $_ == $last } @nodes ) {
        warn 'last not in ring';
        return
    }
    return !!1;
}

1;

__END__

=encoding utf8

=head1 NAME

TVision::ViewLinks - Referenzfreie Verkettung für TGroup/TView 
(owner/next/last/current)

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

  use TVision::ViewLinks qw(:all);

  my $g = bless {}, 'Group';
  my $a = bless {}, 'View';
  my $b = bless {}, 'View';

  insert_first($g, $a);
  insert_after($g, $a, $b);

  my $first = get_first($g);    # $a
  my @kids  = children($g);     # ($a, $b)
  remove_view($g, $a);

=head1 DESCRIPTION

Dieses Modul bildet die klassische TVision-Topologie von C<TGroup>/C<TView>
(C<owner>, C<next>, C<last>, C<current>) in Perl ab, ohne Perl-Referenzen
zwischen den Wrapper-Objekten zu speichern. Stattdessen werden nur noch
numerische Objekt-IDs in C<fieldhashes> gehalten; die Rückauflösung
(ID→Objekt) erfolgt über die L<Hash::Util::FieldHash>-Registry
(C<register>, C<id>, C<id_2obj>). Dadurch ist die Struktur automatisch
GC-sicher und threadsicher, während die TVision-Invarianten erhalten bleiben.

=head2 Ringlisten-Konvention

Wie im Original: Die Views eines C<TGroup> bilden eine kreisförmige
Liste über C<next>. Der Container hält einen Anker C<last>. 
C<first> ist definiert als C<next(last)>.

=head1 EXPORTS

Das Modul exportiert auf Anfrage (C<@EXPORT_OK>):

  set_owner set_next set_last set_current
  get_owner get_next get_last get_current get_first children
  insert_after insert_first remove_view sanity_check

=head1 API

=over 2

=item B<set_owner($view, $group)>

=item B<set_next($view, $next_view)>

=item B<set_last($group, $last_child)>

=item B<set_current($group, $current_child)>

Speichern nur IDs, keine Referenzen. C<undef> löscht den link.

=item B<get_owner($view)> / B<get_next($view)> / B<get_last($group)> / 
B<get_current($group)>

Gibt das Objekt zurück oder C<undef>, falls nicht auflösbar.

=item B<get_first($group)>

Gibt C<next(last($group))> oder C<undef> (leere Gruppe).

=item B<children($group)>

Liefert die Views in Z-Reihenfolge (einmal um den Ring ab C<first>).

=item B<insert_after($group, $target, $new_view)>

Fügt ein und setzt C<owner>; aktualisiert C<last>, falls C<$target> das
letzte View war oder die Gruppe leer war.

=item B<insert_first($group, $new_view)>

Fügt als erstes Kind ein (beachtet Ring-Invarianten).

=item B<remove_view($group, $view)>

Löst C<$view> aus der Ringliste, passt C<last> an und setzt C<owner>/<next>
auf C<undef>. Liefert wahr bei Erfolg.

=item B<sanity_check($group)>

Prüft die wichtigsten Invarianten; liefert C<undef> bei Erfolg oder einen
Fehlertext.

=back

=head1 INVARIANTEN

=over 2

=item * Leere Gruppe: C<last == undef>, C<first == undef>.

=item * Nicht leer: C<first == next(last)>.

=item * Einzelelement-Ring: C<next(first) == first> und C<last == first>.

=item * Alle Kinder besitzen C<owner == $group> und bilden eine zirkuläre Liste.

=back

=head1 IMPLEMENTIERUNGSHINWEISE

=over 2

=item * Die Registry aus L<Hash::Util::FieldHash> (C<register>, C<id>, 
C<id_2obj>) ermöglicht referenzfreie Speicherung und sichere Rückauflösung 
(GC- und threadsicher).

=item * Es werden bewusst keine C<Scalar::Util::weaken>-Verweise benötigt,
da ausschließlich IDs gespeichert werden.

=back

=head1 AUTOR

J. Schneider

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 J. Schneider.

Dieses Dokument darf unter den gleichen Bedingungen wie das Projekt 
F<github.com/brickpool/TVision> verwendet und angepasst werden.

=cut
