import sequtils, std/enumerate, random, strutils
const PAIRS = 10
const m_names = ["abe", "bob", "col", "dan", "ed", "fred", "gav", "hal", "ian", "jon"]
const f_names = ["abi", "bea", "cath", "dee", "eve", "fay", "gay", "hope",
    "ivy", "jan"]
const m_prefs = [
["abi", "eve", "cath", "ivy", "jan", "dee", "fay", "bea", "hope", "gay"],
["cath", "hope", "abi", "dee", "eve", "fay", "bea", "jan", "ivy", "gay"],
["hope", "eve", "abi", "dee", "bea", "fay", "ivy", "gay", "cath", "jan"],
["ivy", "fay", "dee", "gay", "hope", "eve", "jan", "bea", "cath", "abi"],
["jan", "dee", "bea", "cath", "fay", "eve", "abi", "ivy", "hope", "gay"],
["bea", "abi", "dee", "gay", "eve", "ivy", "cath", "jan", "hope", "fay"],
["gay", "eve", "ivy", "bea", "cath", "abi", "dee", "hope", "jan", "fay"],
["abi", "eve", "hope", "fay", "ivy", "cath", "jan", "bea", "gay", "dee"],
["hope", "cath", "dee", "gay", "bea", "abi", "fay", "ivy", "jan", "eve"],
["abi", "fay", "jan", "gay", "eve", "bea", "dee", "cath", "ivy", "hope"]
]
const f_prefs = [
["bob", "fred", "jon", "gav", "ian", "abe", "dan", "ed", "col", "hal"],
["bob", "abe", "col", "fred", "gav", "dan", "ian", "ed", "jon", "hal"],
["fred", "bob", "ed", "gav", "hal", "col", "ian", "abe", "dan", "jon"],
["fred", "jon", "col", "abe", "ian", "hal", "gav", "dan", "bob", "ed"],
["jon", "hal", "fred", "dan", "abe", "gav", "col", "ed", "ian", "bob"],
["bob", "abe", "ed", "ian", "jon", "dan", "fred", "gav", "col", "hal"],
["jon", "gav", "hal", "fred", "bob", "abe", "col", "ed", "dan", "ian"],
["gav", "jon", "bob", "abe", "ian", "dan", "hal", "ed", "col", "fred"],
["ian", "col", "hal", "gav", "fred", "bob", "abe", "ed", "jon", "dan"],
["ed", "hal", "gav", "abe", "bob", "jon", "col", "ian", "fred", "dan"]
]

# recipient's preferences hold the preference score for each contender's id
func get_rec_prefs[N: static int](prefs: array[N, array[N, string]],
    names: openArray[string]): seq[seq[int]] {.compileTime.} =
  for pref_seq in prefs:
    var p = newSeq[int](PAIRS)
    for contender in 0..<PAIRS:
      p[contender] = pref_seq.find(m_names[contender])
    result.add(p)

# contender's preferences hold the recipient ids in descending order of preference
func get_cont_prefs(prefs: array[PAIRS, array[PAIRS, string]], names: openArray[
    string]): seq[seq[int]] {.compileTime.} =
  for pref_seq in prefs:
    var p: seq[int]
    for pref in pref_seq:
      p.add(names.find(pref))
    result.add(p)

const RECIPIENT_PREFS = get_rec_prefs(f_prefs, m_names)
const CONTENDER_PREFS = get_cont_prefs(m_prefs, f_names)

proc print_couples(cont_pairs: seq[int]) =
  for c, r in enumerate(cont_pairs):
    echo m_names[c] & " 💑" & f_names[cont_pairs[c]]

func pair(): (seq[int], seq[int]) =
  # double booking to avoid inverse lookup using find
  var rec_pairs = newSeqWith(10, -1)
  var cont_pairs = newSeqWith(10, -1)
  proc engage(c, r: int) =
    #echo f_names[r] & " accepted " & m_names[c]
    cont_pairs[c] = r
    rec_pairs[r] = c
  var cont_queue = newSeqWith(10, 0)
  while cont_pairs.contains(-1):
    for c in 0..<PAIRS:
      if cont_pairs[c] == -1:
        let r = CONTENDER_PREFS[c][cont_queue[c]] #proposing to first in queue
        cont_queue[c]+=1 #increment contender's queue for future iterations
        let cur_pair = rec_pairs[r] # current pair's index or -1 = vacant
        if cur_pair == -1:
          engage(c, r)
        # contender is more preferable than current
        elif RECIPIENT_PREFS[r][c] < RECIPIENT_PREFS[r][cur_pair]:
          cont_pairs[cur_pair] = -1 # vacate current pair
          #echo m_names[cur_pair] & " was dumped by " & f_names[r]
          engage(c, r)
  result = (cont_pairs, rec_pairs)

proc rand_pair(max: int): (int, int) =
  let a = rand(max)
  var b = rand(max-1)
  if b == a:
    b = max
  result = (a,b)

proc perturb_pairs(cont_pairs, rec_pairs: var seq[int]) =
  randomize()
  let (a,b) = rand_pair(PAIRS-1)
  echo "Swapping " & m_names[a] & " & " & m_names[b] & " partners"
  swap(cont_pairs[a], cont_pairs[b])
  swap(rec_pairs[cont_pairs[a]], rec_pairs[cont_pairs[b]])

proc check_stability(cont_pairs, rec_pairs: seq[int]): bool =
  for c in 0..<PAIRS: # each contender
    let cur_p_score = CONTENDER_PREFS[c].find(cont_pairs[c]) # pref. score for current pair
    for preferred_id in 0..<cur_p_score: # try every recipient with higher score
      let check_r = CONTENDER_PREFS[c][preferred_id]
      let cur_r_p = rec_pairs[check_r] # current pair of checked recipient
      # if score of the cur_r_p is worse (>) than score of checked contender
      if RECIPIENT_PREFS[check_r][cur_r_p] > RECIPIENT_PREFS[check_r][c]:
        echo m_names[c] & " prefers " & f_names[check_r] & " over " & f_names[cont_pairs[c]]
        echo f_names[check_r] & " prefers " & m_names[c] & " over " & m_names[cur_r_p]
        return false # unstable
  result = true

when isMainModule:
  var (cont_pairs, rec_pairs) = pair()
  print_couples(cont_pairs)
  echo "Current pair analysis:"
  echo if check_stability(cont_pairs, rec_pairs):
    "✓ Stable"
  else:
    "✗ Unstable"
  perturb_pairs(cont_pairs, rec_pairs)
  print_couples(cont_pairs)
  echo "Current pair analysis:"
  echo if check_stability(cont_pairs, rec_pairs):
    "✓ Stable"
  else:
    "✗ Unstable"
