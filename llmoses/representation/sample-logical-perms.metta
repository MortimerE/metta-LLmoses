;; ============================================================================
;; llmoses/representation/sample-logical-perms.metta
;;
;; Drop-in replacement for representation/sample-logical-perms.metta — do NOT
;; import the upstream file. Sampling evidence is emitted after merge by
;; state_builder.py. Helpers genPairs / genTriplet / getArgs / getMoveArgs are
;; inlined here so no upstream import is needed.
;;
;; Phase II lever 5 (atom prior): the draw over enumerated combinations goes
;; through llmWeightedSelector. Python gates it — begin_combo_draw returns 0
;; whenever the atom_prior lever is off, and the native lazyRandomSelector
;; then runs UNTOUCHED (no behavioral deviation). When on, each pick is a
;; without-replacement weighted draw whose combo weights come from the
;; response's per-atom prior via the width-generic aggregate (D-027); a
;; zero-mass pool degrades to uniform with a bias_degraded audit row.
;;
;; D-033 contextual application: the selector also carries the exemplar
;; node's operator and its node id (= tree path) into begin_combo_draw, so
;; contextual atom priors (clause_type / parent_operator / depth_bucket /
;; polarity / exemplar_id) and combination_synergy can condition the weights.
;; The 3-arg sampler entrypoints remain as shims passing an empty path
;; (context-free draw) for any caller not forked to thread the node id.
;; ============================================================================

;; --- Phase II lever 5: weighted without-replacement selector ---------------
(= (llmWeightedSelector $lower $upper $n $combos $labels $op $nodePath)
   (let* (($on (py-call (state_builder.begin_combo_draw $combos $labels $op $nodePath))))
     (if (== $on 1)
         (llmWeightedPickLoop $lower $upper $n ())
         (lazyRandomSelector $lower $upper $n))))

(= (llmWeightedPickLoop $lower $upper $n $picked)
   (if (<= $n 0)
       $picked
       (chain (py-call (state_builder.weighted_combo_pick $lower $upper $picked)) $rand
           (llmWeightedPickLoop $lower $upper (- $n 1) (union-atom $picked ($rand))))))

;; --- inlined helpers from representation/sample-logical-perms ---

(= (genPairs $list)
    (let*
        (
            ($x (superpose $list))
            ($y (superpose $list))
        )
        (if (not (== $x $y))
            ($x $y)
            (empty)
        )
    )
)

(= (genTriplet $list)
    (let*
        (
            ($x (superpose $list))
            ($y (superpose $list))
            ($z (superpose $list))
        )
        (if (and (and (!= $x $y) (!= $y $z)) (!= $x $z))
            ($x $y $z)
            (empty)
        )
    )
)

(= (getArgs $swapedOp $PermPairs $picked $argLabels)
    (let*
        (
            (($a $b) (index-atom $PermPairs (superpose $picked)))
            (($1 $2) ((index-atom $argLabels $a) (index-atom $argLabels $b)))
        )
        (if (< $b $a)
            ($swapedOp $2 $1)
            ($swapedOp (NOT $1) $2)
        )
    )
)

(= (getMoveArgs $op $PermPairs $picked $moveLabels)
    (let*
        (
            (($a $b $c) (index-atom $PermPairs (superpose $picked)))
            (($move1 $move2 $move3) ((index-atom $moveLabels $a) (index-atom $moveLabels $b) (index-atom $moveLabels $c)))
        )
        ($op $move1 $move2 $move3)
    ))

;; --- overlay definitions ---

(= (sampleLogicalPerms $op $arity $argLabels $nodePath)
    (let*
        (
            ($swapedOp (swapAndOr $op))
            ($list (genList (- $arity 1)))
            ($idxPairs (collapse (genPairs $list)))
            ($nPairs $arity))
            (if (<= $nPairs 1)
                (let $arg (car-atom $argLabels) ($arg (NOT $arg)))
                (let* (($upperbound (- (* $arity (- $arity 1)) 1))
                        ($picked (llmWeightedSelector 0 $upperbound $nPairs $idxPairs $argLabels $op $nodePath))
                        ($perms (collapse (getArgs $swapedOp $idxPairs $picked $argLabels))))
                   (concatT $argLabels $perms)))))

;; Context-free shim: callers that do not thread a node id draw without
;; positional context (depth/exemplar-conditioned entries simply never match).
(= (sampleLogicalPerms $op $arity $argLabels)
   (sampleLogicalPerms $op $arity $argLabels ()))

(= (sampleStrategyPerms $op $arity $moveLabels $nodePath)
    (let*
        (
            ($list (genList (- (length $moveLabels) 1)))
            ($idxPairs (collapse (genTriplet $list)))
            ($nPairs $arity)
        )
        (if (<= $nPairs 1)
            ($op (car-atom $moveLabels))
            (let*
                (
                    ($upperbound (- (length $idxPairs) 1))
                    ($picked (llmWeightedSelector 0 $upperbound $nPairs $idxPairs $moveLabels $op $nodePath))
                    ($perms (collapse (getMoveArgs $op $idxPairs $picked $moveLabels)))
                )
                   $perms
            )
        )
))

(= (sampleStrategyPerms $op $arity $moveLabels)
   (sampleStrategyPerms $op $arity $moveLabels ()))
