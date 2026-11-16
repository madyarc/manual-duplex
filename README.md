# manual-duplex

Manual two-sided printing for CUPS on Arch Linux — the Linux counterpart of
the "manual duplex" option in HP's Windows drivers.

Choosing "odd pages", printing, flipping, then "even pages" in the print
dialog breaks as soon as you use **2 pages per sheet** or any other layout,
because the odd/even selection runs on the *document* pages, not the
printed sheets. manual-duplex splits the job *after* the layout is applied:

```
 app ──▶ print dialog ──▶ "Manual_Duplex" queue (cups-pdf)
         (2 per sheet,        │ finished job as PDF
          page size, …)       ▼
                    ~/.cache/manual-duplex/spool/
                              │ manual-duplex.path (systemd user unit)
                              ▼
                    manual-duplex process  (qpdf)
                       ├─ fronts: sheets 1,3,5,…  ──▶ lp  ──▶ prints now
                       └─ backs:  sheets 2,4,6,…  ──▶ lp -H hold ──▶ waits
                                                           │
                         flip the stack, then "Print backs" ┘
```

## Install

```sh
git clone https://github.com/madyarc/manual-duplex
cd manual-duplex
makepkg -si
```

Dependencies: `cups`, `cups-pdf`, `qpdf`, `poppler` (for `pdfinfo`),
`systemd`; optionally `libnotify` for the notification button.
On other distributions, `sudo make install` does the same (`PREFIX=/usr/local`
works too).

## Setup

```sh
sudo manual-duplex setup-printer HP_LaserJet  # creates Manual_Duplex, same paper size as your printer
manual-duplex enable                          # as your user: starts manual-duplex.path
manual-duplex config PRINTER HP_LaserJet      # your real printer, see `lpstat -e`
manual-duplex test                            # calibrate once (below)
```

Re-run `sudo manual-duplex setup-printer <queue>` after upgrading from 0.1.0 to
get the Two-Sided option in print dialogs.

If `PRINTER` is left empty the CUPS default destination is used — so don't
make `Manual_Duplex` your default printer.

### Calibrate with the test print

`manual-duplex test` prints a 4-page, 2-sheet test document: the fronts print
immediately, the backs are held. Put the printed stack back into the input
tray so the blank side gets printed, **note exactly how you did it**, then run
`manual-duplex release` (or click **Print backs** in the notification).

Check by turning each sheet over its **long edge**, like a page in a book.
You want sheet 1 = pages 1 and 2, sheet 2 = pages 3 and 4, everything upright.

| Result | Fix |
|---|---|
| back of sheet 1 shows **4** | `manual-duplex config REVERSE_BACKS toggle` |
| the 2 is upside down | `manual-duplex config ROTATE_BACKS toggle` |
| backs printed over the fronts | load the stack the other side up — a physical fix, no setting |

From then on, always reload the stack the way you did in the test. The way
you put paper back never changes; the long/short edge choice below is done
in software.

### Long edge or short edge

Like a real duplex printer, every job is set for one of two ways of turning
the finished sheet over:

- **Long edge** (default) — like a book. Normal for portrait documents.
- **Short edge** — like a flip-over notepad. Usually right for landscape
  documents and for **2 pages per sheet**, where the pages sit sideways on
  the paper.

Pick it in the print dialog's **Two-Sided** option on the Manual_Duplex
printer (*Long Edge*, *Short Edge*, or *Off*, which prints one-sided without
splitting). For short edge, manual-duplex turns the backs by 180° on top of
your calibration, so you still reload the stack the same way.

## Daily use

1. Print from any application to **Manual_Duplex**, with whatever layout you
   like (2 per sheet, page ranges, …), and choose **Two-Sided: Long Edge** or
   **Short Edge**.
2. The fronts come out of the real printer. A notification says so.
3. Flip the stack the way you calibrated, load it, and click **Print backs**
   — or run `manual-duplex release`, or release the held job in your print
   queue window (`system-config-printer`, KDE's print queue, or
   `lp -i <job-id> -H resume`).

Odd page counts work: the last sheet gets a blank back so every sheet passes
through the printer again and the stack stays aligned.

A PDF already on disk can skip the virtual printer:
`manual-duplex print [--long-edge|--short-edge|--one-sided] file.pdf`.

## Commands

```
manual-duplex print [EDGE] FILE.pdf split FILE.pdf and print it
                                    EDGE: --long-edge | --short-edge | --one-sided
manual-duplex test                  2-sheet calibration print
manual-duplex release [JOB-ID]      print held backs (latest job by default)
manual-duplex status                settings, queues, held jobs
manual-duplex config [KEY [VALUE]]  show or change a setting
manual-duplex enable | disable      start/stop watching the spool folder
manual-duplex process [FILE...]     what the systemd service runs
sudo manual-duplex setup-printer [QUEUE]
                                    create Manual_Duplex (paper size from QUEUE)
sudo manual-duplex remove-printer   delete it
```

## Settings

Stored in `~/.config/manual-duplex/config` (see [`config.example`](config.example)).

| Key | Default | Meaning |
|---|---|---|
| `PRINTER` | CUPS default | real printer queue |
| `REVERSE_BACKS` | `no` | print backs last-to-first |
| `ROTATE_BACKS` | `0` | calibration: `180` if long-edge backs come out upside down |
| `FLIP` | `long` | edge for `manual-duplex print` and for jobs that don't say |
| `LP_OPTIONS` | empty | extra `lp` options for both jobs, e.g. `-o media=A4` |
| `KEEP_PDFS` | `no` | keep processed PDFs in `~/.cache/manual-duplex/done` |
| `NOTIFY` | `yes` | desktop notifications |

Both jobs are always sent with `-o sides=one-sided -o number-up=1`, because
the layout is already in the PDF.

## How it works

- **`/etc/cups/cups-pdf-Manual_Duplex.conf`** — cups-pdf supports several
  instances: the queue's device URI `cups-pdf:/Manual_Duplex` makes the
  backend read this file instead of `cups-pdf.conf`, so an existing PDF
  printer is not affected. It writes each job, as the printing user, to
  `~/.cache/manual-duplex/spool/job_<id>-<title>.pdf`.
- **`setup-printer`** copies the cups-pdf PPD, adds a *Two-Sided* option
  (cups-pdf ignores it) and sets the default paper size to your printer's.
- **`manual-duplex.path`** (systemd user unit) starts `manual-duplex.service`
  whenever that folder is not empty.
- **`manual-duplex process`** waits until cups-pdf has finished writing the
  file, reads the job's Two-Sided choice back from CUPS (`ipptool`,
  Get-Job-Attributes on the job id in the file name), splits it with `qpdf`,
  turns the backs by `ROTATE_BACKS` (+180° for short edge), submits the fronts with `lp` and the backs with
  `lp -H hold`, and removes the PDF (or moves it to `failed/` on error, so the
  path unit never loops). Held job IDs are recorded in
  `~/.cache/manual-duplex/held-jobs` for `manual-duplex release`.

## Troubleshooting

- **Nothing happens after printing:** `manual-duplex status`, then
  `journalctl --user -u manual-duplex.service` and `lpstat -t`. Check that
  `~/.cache/manual-duplex/spool` gets a PDF; if not, look at
  `/var/log/cups/cups-pdf-Manual_Duplex_log` (set `LogType 7` in the conf for
  more detail) and `/var/log/cups/error_log`.
- **Home directory on NFS / encrypted mount:** cups-pdf runs from CUPS, so
  the spool folder has to be writable by the printing user while you print.
- **Copies:** print one copy at a time. Multiple copies inside one job would
  be split as one long document.
- **Failed jobs** are kept in `~/.cache/manual-duplex/failed/`; reprint one
  with `manual-duplex print <file>`.

## Uninstall

```sh
manual-duplex disable
sudo manual-duplex remove-printer
sudo pacman -R manual-duplex
```

## License

MIT
