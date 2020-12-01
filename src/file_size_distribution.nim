import os, strutils, math, terminal, fusion/btreetables

const HistogramBlocks = ["█","▉","▊","▋","▌","▍","▎","▏"]
const ProgressChars = ["▀", "▜", "▐", "▟", "▄", "▙", "▌", "▛"]

type
  Stat = object
    filesSeen: BiggestInt
    totalSize: BiggestInt
    maxSize: BiggestInt
    minSize: BiggestInt

type
  FsStat = object
    stat: Stat
    table: CountTable[BiggestInt]

func initStat(): Stat =
  Stat(
    filesSeen: 0,
    totalSize: 0,
    maxSize: -1,
    minSize: BiggestInt.high()
  )

func initFsStat(): FsStat =
  FsStat(
    stat: initStat(),
    table: initCountTable[BiggestInt](1024)
  )

template incStatsTmpl(s: Stat; size: BiggestInt) =
  s.minSize = min(s.minSize, size)
  s.maxSize = max(s.maxSize, size)
  s.totalSize += size
  s.filesSeen.inc()

func getLog2Stats(fs: FsStat): seq[Stat] =
  let bins =
    if fs.stat.maxSize < 0:
      0
    else:
      toInt(floor(log2(toBiggestFloat(fs.stat.maxSize)) / 2)) + 1    
  for n in 0..bins:
    result.add(initStat())
  for size, n in fs.table.pairs:
    for _ in 1..n:
      let bin = if size == 0:
          0
        else:
          toInt(floor(log2(toBiggestFloat(size)) / 2)) + 1    
      incStatsTmpl(result[bin], size)

func drawBar(num, maxNum: Natural; width: Natural): string =
  let f = toFloat(num) / toFloat(maxNum) * toFloat(width)
  let full = toInt(floor(f))
  let tail = f - trunc(f)
  var partial = toInt(round(7.0*tail))
  if partial == 0 and full == 0 and num > 0:
    partial = 1
  for _ in 1..full:
    result.add(HistogramBlocks[0])
  if partial > 0:
    result.add(HistogramBlocks[^partial])

proc progressUpdate(mainThreadBusy: ptr bool) {.thread.} =
  while mainThreadBusy[]:
    for i in 0..7:
      stdout.write("\r", ProgressChars[i], " Scanning the file system...")
      flushFile(stdout)
      sleep(250)

proc walkFs(path: string): FsStat =
  var fs = initFsStat()
  var check = 0
  var thProgress: Thread[ptr bool]
  var mainThreadBusy = true
  createThread(thProgress, progressUpdate, addr mainThreadBusy)
  for file in walkDirRec(path, {pcFile}, {pcDir}):
    let fInfo = getFileInfo(file, false)
    let fSize = fInfo.size
    fs.stat.filesSeen.inc()
    check.inc()
    fs.stat.totalSize += fSize
    fs.stat.maxSize = max(fs.stat.maxSize,fSize)
    fs.stat.minSize = min(fs.stat.minSize,fSize)
    fs.table.inc(fSize)
  mainThreadBusy = false
  stdout.write("\r")
  result = move(fs)

when isMainModule:
  var startPath = if paramCount() > 0:
      paramStr(1)
    else:
      getCurrentDir()
  let startInfo = getFileInfo(startPath)
  if startInfo.kind != pcDir and not startInfo.permissions.contains(fpUserRead):
    echo("Error reading directory ", startPath)
    quit()
  let fs = walkFs(startPath)
  echo("Files scanned: ", fs.stat.filesSeen, ", total: ", formatSize(fs.stat.totalSize))
  var stats = fs.getLog2Stats()
  echo("Stats for files by size strata; Bars: file count.")
  var statStrSeq: seq[(string,BiggestInt)]
  var maxNum:BiggestInt = 0
  var maxLineLen = 0
  for bin, s in stats.pairs:
    let maxSize = if s.filesSeen == 0: BiggestInt(0) else: s.maxSize
    let line = if bin == 0:
        format("$1: Max: $2; $3 files", [
          align(formatSize(0), 16),
          align(formatSize(maxSize), 11),
          $s.filesSeen
        ])
      else:
        let curStrata = toInt(2.0.pow(toFloat(bin)*2))
        let prevStrata = toInt(2.0.pow(toFloat(bin-1)*2))
        format("$1$2: Max: $3; $4 files", [
          alignLeft(formatSize(prevStrata) & "<", 8, '.'),
          align("<" & formatSize(curStrata), 8, '.'),
          align(formatSize(maxSize), 11),
          $s.filesSeen
        ])
    maxLineLen = max(maxLineLen, line.len())
    maxNum = max(maxNum, s.filesSeen)
    statStrSeq.add((line, s.filesSeen))
  let maxWidth = terminalWidth() - maxLineLen - 1
  for (line, n) in statStrSeq:
    let bar = drawBar(n, maxNum, maxWidth)
    echo(alignLeft(line, maxLineLen+1, ' '), bar)
