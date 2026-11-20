#!/usr/bin/env perl
#
# man-tr-stats.pl -- статистика переведённых man-страниц FreeBSD по версиям.
#
# Usage:
#   man-tr-stats.pl [-s LIST] [-q] [--no-dedup] <tr-dir> <meta-file>...
#
#   -s LIST     секции через запятую (по умолчанию: 1,2,5,7,8)
#   -p, --percent  показывать проценты в ячейках (по умолчанию — только tr/tot)
#   -q          тихий режим (только отчёт, без пояснений в stderr)
#   --no-dedup  не схлопывать дубликаты target_path внутри одного meta-файла
#
# <tr-dir>      каталог хранилища переводов (<tr-dir>/<hh>/<orig_hash>)
# <meta-file>…  один или несколько meta/*.tsv; версия = basename без .tsv
#
# Отчёт: строки — версии FreeBSD, столбцы — секции (man1, man2, ...).
# В каждой ячейке: "переведено/всего (процент)".
#
# Exit: 0 — успех; 1 — ошибка использования/ввода; 2 — были кривые строки.

use strict;
use warnings;

my @sections = (1, 2, 5, 7, 8);
my $dedup    = 1;
my $percent  = 0;      # по умолчанию проценты не выводим

while (@ARGV && $ARGV[0] =~ /^-/) {
    my $opt = shift @ARGV;
    if    ($opt eq '-q')         { }   # принимается для совместимости, отчёт и так единственный вывод
    elsif ($opt eq '-p' || $opt eq '--percent') { $percent = 1 }
    elsif ($opt eq '--no-dedup') { $dedup = 0 }
    elsif ($opt eq '-s') {
        die "man-tr-stats.pl: -s требует аргумент\n" unless @ARGV;
        my $list = shift @ARGV;
        @sections = grep { length } split /,/, $list;
        die "man-tr-stats.pl: пустой список секций\n" unless @sections;
    }
    elsif ($opt eq '--') { last }
    else { die "man-tr-stats.pl: неизвестная опция: $opt\n" }
}

die "Usage: $0 [-s LIST] [-p] [-q] [--no-dedup] <tr-dir> <meta-file>...\n"
    unless @ARGV >= 2;

my $tr_dir = shift @ARGV;

die "man-tr-stats.pl: нет такого каталога переводов: $tr_dir\n"
    unless -d $tr_dir;

my %sec_index = map { $_ => 1 } @sections;

# %stats{version}{section} = [ translated, total ]
my %stats;
my $failed = 0;

for my $meta_file (@ARGV) {
    unless (-f $meta_file) {
        warn "man-tr-stats.pl: нет meta-файла: $meta_file\n";
        $failed++;
        next;
    }

    my $base    = $meta_file;
    $base =~ s{.*/}{};
    (my $version = $base) =~ s/\.tsv$//;

    open my $fh, '<', $meta_file
        or do { warn "man-tr-stats.pl: не открыть $meta_file: $!\n"; $failed++; next };

    my %seen_path;   # для дедупликации target_path в пределах файла

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*(?:#|$)/;

        my @f = split /\|/, $line, -1;
        if (@f != 5) {
            warn "man-tr-stats.pl: $meta_file: ожидалось 5 полей, получено "
               . scalar(@f) . ": $line\n";
            $failed++;
            next;
        }

        my ($src_path, $target_path, $orig_hash) = @f[0, 1, 2];

        if (!defined $orig_hash || $orig_hash eq '') {
            warn "man-tr-stats.pl: $meta_file: пустой orig_hash: $line\n";
            $failed++;
            next;
        }

        # секция — суффикс target_path после последней точки (как в sh-скрипте)
        my $bname = $target_path;
        $bname =~ s{.*/}{};
        my ($section) = $bname =~ /\.([^.]+)$/;
        next unless defined $section && $sec_index{$section};

        if ($dedup) {
            next if $seen_path{$target_path}++;
        }

        # переведён ли orig_hash? тот же путь, что в man-tr-candidates.sh
        my $hh      = substr($orig_hash, 0, 2);
        my $tr_file = "$tr_dir/$hh/$orig_hash";
        my $translated = -f $tr_file ? 1 : 0;

        $stats{$version}{$section}[1]++;           # total
        $stats{$version}{$section}[0] += $translated; # translated
    }
    close $fh;

    # гарантируем наличие ключей даже для пустых ячеек
    for my $s (@sections) {
        $stats{$version}{$s} ||= [0, 0];
    }
}

# --- вывод отчёта ---
my @versions = sort {
    # числовые версии — по возрастанию, нечисловые — после, лексикографически
    my ($na, $nb) = ($a =~ /^\d+$/ ? 1 : 0, $b =~ /^\d+$/ ? 1 : 0);
    if ($na && $nb) { return $a <=> $b }
    return $na <=> $nb if $na != $nb;
    return $a cmp $b;
} keys %stats;

# --- предварительно сформировать текстовые ячейки ---
# Это нужно, чтобы ширина колонки учитывала и проценты, и столбец TOTAL.
my %cell;                 # $cell{$version}{$section} = "tr/tot (NN%)"
my %total_cell;           # $total_cell{$section}      = "tr/tot (NN%)"

sub fmt_cell {
    my ($tr, $tot) = @_;
    my $s = sprintf "%d/%d", $tr, $tot;
    if ($percent) {
        if ($tot > 0) {
            $s .= sprintf " (%.0f%%)", 100.0 * $tr / $tot;
        } else {
            $s .= " (—)";
        }
    }
    return $s;
}

for my $v (@versions) {
    for my $s (@sections) {
        my ($tr, $tot) = @{ $stats{$v}{$s} };
        $cell{$v}{$s} = fmt_cell($tr, $tot);
    }
}
# сумма по всем секциям для каждой версии — для правого столбца TOTAL
my %row_total;            # $row_total{$version} = "tr/tot (NN%)"
for my $v (@versions) {
    my ($tr, $tot) = (0, 0);
    for my $s (@sections) {
        $tr  += $stats{$v}{$s}[0];
        $tot += $stats{$v}{$s}[1];
    }
    $row_total{$v} = fmt_cell($tr, $tot);
}

# --- ширина колонок: max(заголовок "manN", все версии, строка TOTAL) ---
my $ver_w = length("Version");
for my $v (@versions) { $ver_w = length($v) if length($v) > $ver_w }
$ver_w = length("TOTAL") if length("TOTAL") > $ver_w;

my @col_w;
for my $i (0 .. $#sections) {
    my $s = $sections[$i];
    my $w = length(" man$s");                  # заголовок
    for my $v (@versions) {                   # ячейки версий
        my $l = length($cell{$v}{$s});
        $w = $l if $l > $w;
    }
    $col_w[$i] = $w;
}

# правый столбец TOTAL: max(заголовок, все ячейки версий)
my $total_w = length("TOTAL");
for my $v (@versions) {
    my $l = length($row_total{$v});
    $total_w = $l if $l > $total_w;
}

# --- вывод ---
printf "%-${ver_w}s", "Version";
for my $i (0 .. $#sections) {
    printf "  %-${col_w[$i]}s", " man$sections[$i]";
}
printf "  %-${total_w}s", "TOTAL";
print "\n";

printf "%-${ver_w}s", "-" x $ver_w;
for my $i (0 .. $#sections) {
    printf "  %-${col_w[$i]}s", "-" x $col_w[$i];
}
printf "  %-${total_w}s", "-" x $total_w;
print "\n";

for my $v (@versions) {
    printf "%-${ver_w}s", $v;
    for my $i (0 .. $#sections) {
        printf "  %-${col_w[$i]}s", $cell{$v}{$sections[$i]};
    }
    printf "  %-${total_w}s", $row_total{$v};
    print "\n";
}

exit($failed ? 2 : 0);
