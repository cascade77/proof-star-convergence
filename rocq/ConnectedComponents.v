Require Import List.
Import ListNotations.
Require Import Arith.
Require Import Lia.


(* graph representation *)

(* a graph is a list of undirected edges. *)
(* we represent each edge as (u, v) with no ordering assumption *)

Definition graph := list ( nat * nat).

(* neighbors of node n in graph g *)
Fixpoint neighbors (n : nat) (g : graph) : list nat :=
match g with
| [] => []
| (u, v) :: rest =>
    if Nat.eqb u n then v :: neighbors n rest
    else if Nat.eqb v n then u :: neighbors n rest
    else neighbors n rest
end.


(* minimum of a list, defualting to d if list is empty *)
Fixpoint list_min (l : list nat) (d : nat) : nat :=
match l with
| [] => d
| x :: rest => Nat.min x (list_min rest d)
end.


(* the label of node n is the minimum among its neighbors,
   falling back to n itself if it has no neighbors *)
Definition label_of (n : nat) (g : graph) : nat :=
  list_min (neighbors n g) n.


  (* one star round *)

(* one round updates every edge endpoint to its current label *)
Definition update_edge (g : graph) (e : nat * nat) : nat * nat :=
  (label_of (fst e) g, label_of (snd e) g).

Definition apply_star (g : graph) : graph :=
  map (update_edge g) g.


 
  
  (* reachability *)

Inductive connected (g : graph) : nat -> nat -> Prop :=
  | conn_refl  : forall u,
      connected g u u
  | conn_edge  : forall u v,
      (In (u, v) g \/ In (v, u) g) ->
      connected g u v
  | conn_trans : forall u w v,
      connected g u w ->
      connected g w v ->
      connected g u v.
      
      

  (* sanity checks *)

Example neighbors_test1 : neighbors 0 [(0,1);(1,2);(0,2)] = [1;2].
Proof. reflexivity. Qed.

Example neighbors_test2 : neighbors 1 [(0,1);(1,2)] = [0;2].
Proof. reflexivity. Qed.

Example list_min_test1 : list_min [3;1;2] 99 = 1.
Proof. reflexivity. Qed.

Example list_min_test2 : list_min [] 5 = 5.
Proof. reflexivity. Qed.

Example label_of_test1 : label_of 0 [(0,1);(0,2)] = 0.
Proof. reflexivity. Qed.

Example label_of_test2 : label_of 3 [(0,1);(1,2)] = 3.
Proof. reflexivity. Qed.

Example label_of_test3 : label_of 2 [(0,1);(1,2)] = 1.
Proof. reflexivity. Qed.

Example apply_star_test1 : apply_star [(0,1)] = [(0,0)].
Proof. reflexivity. Qed.    

Example apply_star_test2 : apply_star [(1,2);(2,3)] = [(1,1);(1,2)].
Proof. reflexivity. Qed.    

      (* lemmas  *)

(* list_min result is <= the default *)
Lemma list_min_le_default : forall l d,
  list_min l d <= d.
Proof.
  intros l d.
  induction l as [| h t IH].
  - simpl. lia.
  - simpl. lia.
Qed.

(* label_of n g <= n always, because n is the fallback default *)
Lemma label_le_self : forall n g,
  label_of n g <= n.
Proof.
  intros n g.
  unfold label_of.
  apply list_min_le_default.
Qed.

(* if x is in the neighbor list, list_min is <= x *)
Lemma list_min_le_member : forall x l d,
  In x l -> list_min l d <= x.
Proof.
  intros x l d Hin.
  induction l as [| h t IH].
  - inversion Hin.
  - simpl in Hin.
    destruct Hin as [-> | Hin].
    + simpl. lia.
    + simpl. 
      specialize (IH Hin).
      lia.
Qed.

(* if v is a neighbor of u, then label_of u g <= v *)
Lemma label_le_neighbor : forall u v g,
  In v (neighbors u g) -> label_of u g <= v.
Proof.
  intros u v g Hin.
  unfold label_of.
  apply list_min_le_member.
  assumption.
Qed.

(* neighbors are symmetric: if (u,v) is in g then v is a neighbor of u *)
Lemma neighbors_fst : forall u v g,
  In (u, v) g -> In v (neighbors u g).
Proof.
  intros u v g Hin.
  induction g as [| (a, b) rest IH].
  - inversion Hin.
  - simpl in Hin.
    destruct Hin as [H | H].
    + injection H as -> ->.
      simpl.
      rewrite Nat.eqb_refl.
      left. reflexivity.
    + simpl.
      destruct (Nat.eqb a u) eqn:Eau.
      * right. apply IH. assumption.
      * destruct (Nat.eqb b u) eqn:Ebu.
        -- right. apply IH. assumption.
        -- apply IH. assumption.
Qed.

Lemma neighbors_snd : forall u v g,
  In (u, v) g -> In u (neighbors v g).
Proof.
  intros u v g Hin.
  induction g as [| (a, b) rest IH].
  - inversion Hin.
  - simpl in Hin.
    destruct Hin as [H | H].
    + injection H as -> ->.
      simpl.
      destruct (Nat.eqb u v) eqn:E.
      * apply Nat.eqb_eq in E. subst.
        left. reflexivity.
      * rewrite Nat.eqb_refl.
        left. reflexivity.
    + simpl.
      destruct (Nat.eqb a v) eqn:Eav.
      * right. apply IH. assumption.
      * destruct (Nat.eqb b v) eqn:Ebv.
        -- right. apply IH. assumption.
        -- apply IH. assumption.
Qed.


(* main theorems *)

(* at fixpoint, label_of is stable: applying update_edge changes nothing.
   this means for every edge (u,v) in g, label_of u g = u and label_of v g = v. *)
Lemma fixpoint_labels_stable : forall g u v,
  apply_star g = g ->
  In (u, v) g ->
  label_of u g = u /\ label_of v g = v.
Proof.
  intros g u v Hfix Hin.
  unfold apply_star in Hfix.
  (* map (update_edge g) g = g, so for the element (u,v),
     update_edge g (u,v) = (u,v) *)
  assert (Helem : update_edge g (u, v) = (u, v)).
  { 
    assert (In (update_edge g (u, v)) (map (update_edge g) g)).
    { apply in_map. assumption. }
    rewrite Hfix in H.
    (* update_edge g (u,v) is in g, and equals (u,v) since map = g *)
    (* we need: map f g = g -> f x = x for x in g *)
    clear H.
    assert (Hmap : forall (A : Type) (f : A -> A) (l : list A) (x : A),
      map f l = l -> In x l -> f x = x).
    {
      intros A f l x Hml Hxin.
      induction l as [| h t IH].
      - inversion Hxin.
      - simpl in Hml.
        injection Hml as Hh Ht.
        simpl in Hxin.
        destruct Hxin as [-> | Hxin].
        + assumption.
        + apply IH; assumption.
    }
    apply Hmap with (l := g); assumption.
  }
  unfold update_edge in Helem.
  simpl in Helem.
  injection Helem as Hu Hv.
  (* label_of u g <= u always, and Hu says label_of u g = u *)
  split.
  - apply Nat.le_antisymm.
    + apply label_le_self.
    + lia.
  - apply Nat.le_antisymm.
    + apply label_le_self.
    + lia.
Qed.

(* at fixpoint, for any edge (u,v), label_of u g = label_of v g.
   both equal their own node id, and both see each other as neighbors,
   forcing their labels to be equal. *)
Theorem fixpoint_same_label : forall g u v,
  apply_star g = g ->
  In (u, v) g ->
  label_of u g = label_of v g.
Proof.
  intros g u v Hfix Hin.
  assert (Hstable := fixpoint_labels_stable g u v Hfix Hin).
  destruct Hstable as [Hu Hv].
  assert (Huv : label_of u g <= v).
  { apply label_le_neighbor. apply neighbors_fst. assumption. }
  assert (Hvu : label_of v g <= u).
  { apply label_le_neighbor. apply neighbors_snd. assumption. }
  lia.
Qed.


Lemma list_min_achieves : forall l d r,
  list_min l d = r ->
  r <> d ->
  In r l.
Proof.
  intros l d r Hmin Hneq.
  induction l as [| h t IH].
  - simpl in Hmin. subst. contradiction.
  - simpl in Hmin.
    destruct (Nat.le_gt_cases h (list_min t d)) as [Hle | Hlt].
    + rewrite Nat.min_l in Hmin by assumption.
      subst. left. reflexivity.
    + rewrite Nat.min_r in Hmin by lia.
      right. apply IH. assumption.
Qed.

Lemma neighbors_in_graph_fst : forall u w g,
  In w (neighbors u g) ->
  In (u, w) g \/ In (w, u) g.
Proof.
  intros u w g Hin.
  induction g as [| (a, b) rest IH].
  - inversion Hin.
  - simpl in Hin.
    destruct (Nat.eqb a u) eqn:Eau.
    + apply Nat.eqb_eq in Eau. subst.
      simpl in Hin.
      destruct Hin as [-> | Hin].
      * left. left. reflexivity.
      * destruct (IH Hin) as [H | H].
        -- left. right. assumption.
        -- right. right. assumption.
    + destruct (Nat.eqb b u) eqn:Ebu.
      * apply Nat.eqb_eq in Ebu. subst.
        simpl in Hin.
        destruct Hin as [-> | Hin].
        -- right. left. reflexivity.
        -- destruct (IH Hin) as [H | H].
           ++ left. right. assumption.
           ++ right. right. assumption.
      * destruct (IH Hin) as [H | H].
        -- left. right. assumption.
        -- right. right. assumption.
Qed.

Lemma neighbors_in_graph_snd : forall u w g,
  In w (neighbors u g) ->
  In (w, u) g \/ In (u, w) g.
Proof.
  intros u w g Hin.
  destruct (neighbors_in_graph_fst u w g Hin) as [H | H].
  - right. assumption.
  - left. assumption.
Qed.


(* the main theorem: at fixpoint, same label implies connected *)

Theorem fixpoint_correct : forall g u v,
  apply_star g = g ->
  label_of u g = label_of v g ->
  connected g u v.
Proof.
  intros g u v Hfix Heq.
  set (m := label_of u g).
  assert (Hmu : label_of u g = m) by reflexivity.
  assert (Hmv : label_of v g = m) by (unfold m; symmetry; assumption).
  assert (Hmu_le : m <= u).
  { unfold m. apply label_le_self. }
  assert (Hmv_le : m <= v).
  { rewrite <- Hmv. apply label_le_self. }
  destruct (Nat.eq_dec m u) as [Hmu_eq | Hmu_neq].
  - destruct (Nat.eq_dec m v) as [Hmv_eq | Hmv_neq].
    + rewrite <- Hmu_eq. rewrite <- Hmv_eq. apply conn_refl.
    + assert (Hin_v : In u (neighbors v g)).
      { unfold label_of in Hmv.
        rewrite Hmu_eq in Hmv.
        apply list_min_achieves in Hmv.
        - assumption.
        - lia. }
      apply conn_edge.
      destruct (neighbors_in_graph_fst v u g Hin_v) as [H | H].
      * right. assumption.
      * left. assumption.
  - destruct (Nat.eq_dec m v) as [Hmv_eq | Hmv_neq].
    + assert (Hin_u : In v (neighbors u g)).
      { unfold label_of in Hmu.
        rewrite Hmv_eq in Hmu.
        apply list_min_achieves in Hmu.
        - assumption.
        - lia. }
      apply conn_edge.
      destruct (neighbors_in_graph_fst u v g Hin_u) as [H | H].
      * left. assumption.
      * right. assumption.
    + apply conn_trans with (w := m).
      * apply conn_edge.
        assert (Hin_u : In m (neighbors u g)).
        { unfold label_of in Hmu.
          apply list_min_achieves in Hmu; assumption. }
        destruct (neighbors_in_graph_fst u m g Hin_u) as [H | H].
        -- left. assumption.
        -- right. assumption.
      * apply conn_edge.
        assert (Hin_v : In m (neighbors v g)).
        { unfold label_of in Hmv.
          apply list_min_achieves in Hmv; assumption. }
        destruct (neighbors_in_graph_fst v m g Hin_v) as [H | H].
        -- right. assumption.
        -- left. assumption.
Qed.


(* connected is symmetric *)
Lemma connected_sym : forall g u v,
  connected g u v -> connected g v u.
Proof.
  intros g u v H.
  induction H.
  - apply conn_refl.
  - apply conn_edge. destruct H as [H | H].
    + right. assumption.
    + left. assumption.
  - apply conn_trans with (w := w).
    + assumption.
    + assumption.
Qed.

(* label_of an isolated node equals itself *)
Lemma isolated_label : forall n g,
  neighbors n g = [] ->
  label_of n g = n.
Proof.
  intros n g H.
  unfold label_of. rewrite H. reflexivity.
Qed.


Theorem fixpoint_iff : forall g u v,
  apply_star g = g ->
  (label_of u g = label_of v g <-> connected g u v).
Proof.
  intros g u v Hfix.
  split.
  - apply fixpoint_correct. assumption.
  - intros Hconn.
    induction Hconn.
    + reflexivity.
    + destruct H as [H | H].
      * apply fixpoint_same_label; assumption.
      * symmetry. apply fixpoint_same_label; assumption.
    + rewrite IHHconn1. assumption.
Qed.

Example fixpoint_correct_test :
  connected [(0,0)] 0 0.
Proof.
  apply conn_refl.
Qed.

Example connected_triangle :
  connected [(0,1);(0,2);(1,2)] 1 2.
Proof.
  apply conn_edge.
  left.
  right. right. left. reflexivity.
Qed.