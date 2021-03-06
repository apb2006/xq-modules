xquery version "3.0";

(:~
 : A simple Skew Heap implementation.
 :
 : @author Leo Woerteler &lt;leo@woerteler.de&gt;
 : @version 0.1
 : @license BSD 2-Clause License
 :)
module namespace heap = 'http://www.woerteler.de/xquery/modules/heap';

import module namespace pair = 'http://www.woerteler.de/xquery/modules/pair'
    at 'pair.xqm';

import module namespace queue = 'http://www.woerteler.de/xquery/modules/queue'
    at 'queue.xqm';

(:~
 : Creates a new empty binary heap with a given comparison function.
 :
 : @param $leq comparison function, returns true() if
 :   the first argument is less-than-or-equal to the second one
 : @return a new empty binary heap
 :)
declare %public function heap:new(
  $leq as function(item()*, item()*) as xs:boolean
) as function(*) {
  pair:new($leq, heap:empty())
};

(:~
 : Check if the given heap is empty.
 : @param $heap the heap to check
 : @return <code>true()</code> if the heap is empty, <code>false()</code> otherwise
 :)
declare %public function heap:is-empty(
  $heap as function(*)
) as xs:boolean {
  heap:extract-min(
    $heap,
    function() { true() },
    function($h, $t) { false() }
  )
};

(:~
 : Inserts a value into a heap.
 :
 : @param $heap heap to insert the value into
 : @param $x value to insert
 : @return the heap where $x is inserted
 :)
declare %public function heap:insert(
  $heap as function(*),
  $x as item()*
) as function(*) {
  pair:deconstruct(
    $heap,
    function($leq, $root) {
      pair:new(
        $leq,
        heap:union(
          $leq,
          function($_, $b) {
            $b(heap:empty(), $x, heap:empty())
          },
          $root
        )
      )
    }
  )
};

(:~
 : Tries to extract the minimum element from this heap and either calls the
 : callback for the non-empty heap with the minimal element and the rest of the heap
 : or the one for the empty heap.
 :
 : @param $heap the heap to extract the minimum from
 : @param $empty callback for the empty heap
 : @param $non-empty callback for the non-empty heap
 : @return result of the callback
 :)
declare %public function heap:extract-min(
  $heap as function(*),
  $empty as function() as item()*,
  $non-empty as function(item()*, function(*)) as item()*
) as item()* {
  pair:deconstruct(
    $heap,
    function($leq, $root) {
      $root(
        $empty,
        function($l, $x, $r) {
          $non-empty($x, pair:new($leq, heap:union($leq, $l, $r)))
        }
      )
    }
  )
};

(:~
 : Sorts the given sequence according to the given less-than predicate.
 : @param $lt less-than predicate
 : @param $seq sequence to sort
 : @return the sorted sequence
 :)
declare %public function heap:sort(
  $lt as function(item(), item()) as item()*,
  $seq as item()*
) as item()* {
  if(empty($seq)) then ()
  else heap:values(
    $lt,
    heap:build(
      fold-left(
        $seq,
        queue:empty(),
        function($q, $it) {
          queue:enqueue(heap:singleton($it), $q)
        }
      ),
      $lt
    ),
    ()
  )
};

(::::::::::::::::::::::::::: private functions :::::::::::::::::::::::::::)

declare %private function heap:build($queue, $cmp) {
  queue:match(
    $queue,
    function() {
      (: empty queue, should not happen :)
      error(xs:QName('heap:EMPTYQUE'), 'empty queue')
    },
    function($h1, $queue2) {
      queue:match(
        $queue2,
        function() {
          (: only one heap left, we are finished :)
          $h1
        },
        function($h2, $queue3) {
          (: at least to heaps, union them and put the result back in the queue :)
          let $h := heap:union($cmp, $h1, $h2)
          return heap:build(queue:enqueue($h, $queue3), $cmp)
        }
      )
    }
  )
};

declare %private function heap:values(
  $cmp as function(item(), item()) as item()*,
  $heap as function(*),
  $seq as item()*
) as item()* {
  $heap(
    function() { $seq },
    function($l, $x, $r) {
      heap:values($cmp, heap:union($cmp, $l, $r), ($seq, $x))
    }
  )
};

declare %private function heap:empty() {
  function($empty, $branch) { $empty() }
};

declare %private function heap:singleton($x) {
  heap:branch(heap:empty(), $x, heap:empty())
};

declare %private function heap:branch($left, $x, $right) {
  function($empty, $branch) {
    $branch($left, $x, $right)
  }
};

declare %private function heap:union($leq, $left, $right) {
  $left(
    function() { $right },
    function($ll, $lx, $lr) {
      $right(
        function() { $left },
        function($rl, $rx, $rr) {
          if($leq($lx, $rx))
            then heap:branch($lr, $lx, heap:union($leq, $ll, $right))
            else heap:branch($rr, $rx, heap:union($leq, $rl, $left))
        }
      )
    }
  )
};
