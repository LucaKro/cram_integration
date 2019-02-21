;;;
;;; Copyright (c) 2018, Alina Hawkin <hawkin@cs.uni-bremen.de>
;;;                     Gayane Kazhoyan <kazhoyan@cs.uni-bremen.de>
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are met:
;;;
;;;     * Redistributions of source code must retain the above copyright
;;;       notice, this list of conditions and the following disclaimer.
;;;     * Redistributions in binary form must reproduce the above copyright
;;;       notice, this list of conditions and the following disclaimer in the
;;;       documentation and/or other materials provided with the distribution.
;;;     * Neither the name of the Institute for Artificial Intelligence/
;;;       Universitaet Bremen nor the names of its contributors may be used to
;;;       endorse or promote products derived from this software without
;;;       specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
;;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;;; POSSIBILITY OF SUCH DAMAGE.

(in-package :kvr)

(defun navigate-and-look-and-detect (?base-poses ?look-poses ?type)
  "Moves the robot into the position which the human had when interacting
with an object. The robot is placed at the spot where the human was standing and
is looking at the spot where the object was in Virtual Reality.
`?base-pose': The position for the robot base. Aka, where the human feet were.
`?look-pose': The position which the object had in Virtual Reality, and
where the robot should be looking at.
RETURNS: Errors or a successfull movement action of the robot."

  (let ((?obj-type (object-type-filter-bullet ?type)))

    ;; park arms
    (exe:perform
     (desig:an action
               (type positioning-arm)
               (left-configuration park)
               (right-configuration park)))

    ;; move the robot to specified base location
    ;; pick one of the base-poses from the lazy list
    (let ((?base-pose (cut:lazy-car ?base-poses)))

      ;; if the going action fails, pick another base-pose from the lazy list
      (cpl:with-failure-handling
          ((common-fail:navigation-low-level-failure (e)
             (declare (ignore e))
             (roslisp:ros-warn (kvr plans) "Navigation failed. Next solution.")
             (setf ?base-poses (cut:lazy-cdr ?base-poses))
             (setf ?base-pose (cut:lazy-car ?base-poses))
             (when ?base-pose
               (cpl:retry))))

        ;; do the going
        (exe:perform
         (desig:an action
                   (type going)
                   (target (desig:a location (pose ?base-pose))))))

      ;; move the head to look at specified location (most probably that of an obj)
      ;; pick one looking target
      ;; and detect
      (let ((?look-pose (cut:lazy-car ?look-poses)))

        ;; if detection fails, try another looking target
        (cpl:with-failure-handling
            ((common-fail:perception-low-level-failure (e)
               (declare (ignore e))
               (roslisp:ros-warn (kvr plans)
                                 "Perception failed. Next solution.")
               (setf ?look-poses (cut:lazy-cdr ?look-poses))
               (setf ?look-pose (cut:lazy-car ?look-poses))
               (when ?look-pose
                 (cpl:retry))))

          ;; do the looking
          (exe:perform
           (desig:an action
                     (type turning-towards)
                     (target (desig:a location (pose ?look-pose)))))

          ;; perceive
          (exe:perform
           (desig:an action
                     (type detecting)
                     (object (desig:an object (type ?obj-type))))))))))


(defun detect-navigate-and-pick-up (?base-poses ?type)
  (declare (ignore ?base-poses))
  "Picks up an object of the given type.
`?type' is the type of the object that is to be picked up as a simple symbol.
RETURNS: Errors or an object designator of picked up object"
  (let* ((?arm (car (query-hand (object-type-filter-prolog ?type))))
         (?obj-type (object-type-filter-bullet ?type)))

    ;; move the robot to specified base location
    ;; pick one of the base-poses from the lazy list
    ;; (let ((?base-pose (cut:lazy-car ?base-poses)))

    ;;   ;; if the going action fails, pick another base-pose from the lazy list
    ;;   (cpl:with-failure-handling
    ;;       ((common-fail:navigation-low-level-failure (e)
    ;;          (roslisp:ros-warn (kvr plans) "Navigation failed. Next solution.")
    ;;          (setf ?base-poses (cut:lazy-cdr ?base-poses))
    ;;          (setf ?base-pose (cut:lazy-car ?base-poses))
    ;;          (when ?base-pose
    ;;            (cpl:retry))))

    ;;     ;; drive closer
    ;;     (exe:perform
    ;;      (desig:an action
    ;;                (type going)
    ;;                (target (desig:a location (pose ?base-pose)))))))

    ;; reperceive from pick-up position
    (let ((?obj-desig
            (exe:perform
             (desig:an action
                       (type detecting)
                       (object (desig:an object (type ?obj-type)))))))

      ;; print picking up resolved
      (roslisp:ros-info (kvr plans)
                        "picking-up action got referenced to ~a"
                        (desig:reference
                         (desig:an action
                                   (type picking-up)
                                   (arm ?arm)
                                   (grasp human-grasp)
                                   (object ?obj-desig))))
      ;; pick up
      (exe:perform
       (desig:an action
                 (type picking-up)
                 (arm ?arm)
                 (grasp human-grasp)
                 (object ?obj-desig)))

      ?obj-desig)))


(defun fetch-object (?searching-base-poses ?searching-look-poses
                     ?grasping-base-poses ?type)
  "A plan to fetch an object.
?GRASPING-BASE-POSE: The pose at which the human stood to pick up the object.
?GRASPING-LOOK-POSE: The pose at which the object was standing when picked up,
and at which the robot will look for it.
?TYPE: the type of the object the robot should look for and which to pick up.
RETURNS: The object designator of the object that has been picked up in this plan."
  (navigate-and-look-and-detect ?searching-base-poses ?searching-look-poses ?type)
  (detect-navigate-and-pick-up ?grasping-base-poses ?type))

(defun deliver-object (?placing-base-pose ?placing-look-pose ?place-pose
                       ?obj-desig ?type)
  "A plan to place an object which is currently in one of the robots hands.
?PLACING-BASE-POSE: The pose the robot should stand at in order to place the
object. Usually the pose where the human was standing while placing the object
in Virtual Reality.
?PLACING-LOOK-POSE: The pose where the robot looks at while placing the object.
The same pose at which the human placed the object.
?PLACE-POSE: The pose at which the object was placed in Virtual Reality.
Relative to the Kitchen Island table.
?OBJ-DESIG: The object deignator of the the object which the robot currently
holds in his hand and which is to be placed."
  (let* ((?arm (car
                (query-hand
                 (object-type-filter-prolog
                  (desig:desig-prop-value ?obj-desig :type))))))
    ;; navigate
    (navigate-and-look-and-detect ?placing-base-pose ?placing-look-pose ?type)
    ;; place obj
    (exe:perform
     (desig:an action
               (type placing)
               (arm ?arm)
               (object ?obj-desig)
               (target (desig:a location (pose ?place-pose)))))
    ;; park arms
    (exe:perform
     (desig:an action
               (type positioning-arm)
               (left-configuration park)
               (right-configuration park)))))

(defun transport (?searching-base-poses ?searching-look-poses ?grasping-base-poses
                  ?placing-base-poses ?placing-look-poses ?place-poses ?type)
  "Picks up and object and places it down based on Virtual Reality data.
?GRASPING-BASE-POSE: The pose the robot should stand at, in order to be able to
grasp the object.
?GRASPING-LOOK-POSE: The pose the robot is going to look at, in order to look
for the object to be picked up.
?PLACING-BASE-POSE: The pose where the robot should stand in order to be able
to place down the picked up object.
?PLACING-LOOK-POSE: The pose the robot is looking at, at which he will place
the object.
?PLACE-POSE: The actual placing pose of the object.
?TYPE: The type of the object the robot should interact with."
  ;; fetch the object
  (let ((?obj-desig (fetch-object
                     ?searching-base-poses ?searching-look-poses ?grasping-base-poses
                     ?type)))
    ;; deliver the object
    (deliver-object
     ?placing-base-poses ?placing-look-poses ?place-poses ?obj-desig ?type)))