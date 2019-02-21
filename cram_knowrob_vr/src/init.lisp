;;;
;;; Copyright (c) 2018, Alina Hawkin <hawkin@cs.uni-bremen.de>
;;;                      Gayane Kazhoyan <kazhoyan@cs.uni-bremen.de>
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

;;; initializes the episode data by connecting to OpenEase and loads the Episode data within OpenEase
;;; contains paths to the Episode data and SemanticMap
;;; which might need to be adjusted, if other episode data is to be loaded. 

;;; care to give the right rcg stamp
;;; rcg_c is for finding out the displacement
;;; rcg_f has the to date better grasps
;;; eval2 has best full set pick and place
;;; rcg_d different grasps
(in-package :kvr)

(defvar *episode-path*
  "/home/cram/ros/episode_data/episodes/Own-Episodes/set-clean-table/"
  "path of where the episode data is located")

(defun load-multiple-episodes (&optional namedir-list)
  ;;make a list of all directories of episodes and load them
  (unless namedir-list
    (setf namedir-list
          (mapcar #'directory-namestring
                  (uiop:subdirectories *episode-path*))))
  (mapcar #'(lambda (namedir)
              (u-load-episodes (concatenate 'string namedir "Episodes/"))
              (owl-parse (concatenate 'string namedir "SemanticMap.owl"))
              (connect-to-db "Own-Episodes_set-clean-table"))
          namedir-list))

(defun init-episode (&optional namedir-list)
  "Initializes the node and loads the episode data from knowrob via json_prolog.
The path of the episode files is set in the *episode-path* variable.
`namedir' is name of the episode file directory which is to be loaded.
The path is individual and therefore hardcoded one"
  (ros-info (kvr) "initializing the episode data and connecting to database...")
  ;; (start-ros-node "cram_knowrob_vr")
  (register-ros-package "knowrob_robcog")
  (register-ros-package "knowrob_maps")
  (load-multiple-episodes namedir-list)
  (map-marker-init))

;;;;;;;;;;;;;;;;;;;;;;;; BULLET WORLD INITIALIZATION ;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spawn-semantic-map ()
  (setf btr:*mesh-path-whitelist* *mesh-path-whitelist-unreal-kitchen*)
  (prolog:prolog
   `(and (btr:bullet-world ?world)
         (assert (btr:object ?world :semantic-map :semantic-map-kitchen
                             ((,*semantic-map-offset-x*
                               ,*semantic-map-offset-y*
                               0)
                              (0 0 0 1)))))))

(defun spawn-urdf-items ()
  "Spawns all the objects the robot interacts with."
  (ros-info (kvr) "spawning objects for experiments...")
  ;; (btr-utils:kill-all-objects)
  ;; (btr:detach-all-objects (btr:get-robot-object))
  (btr:add-objects-to-mesh-list "cram_knowrob_vr")
  (let ((object-types '(:edeka-red-bowl :koelln-muesli-knusper-honig-nuss
                        :fork-blue-plastic :cup-eco-orange :weide-milch-small)))
    ;; spawn objects at default poses
    (let ((objects (mapcar (lambda (object-type)
                             (btr-utils:spawn-object
                              object-type object-type :color '(1 0 0)))
                           object-types)))
      objects))

  (btr-utils:spawn-object :axes :axes :color '(0 1 1))
  (btr-utils:spawn-object :axes :axes2 :color '(0 1 1))
  (btr-utils:spawn-object :axes :axes3 :color '(0 1 1)))

(defun spawn-semantic-items ()
  "Spawns all objects of the current Episode on their original position in the
semantic map kitchen."
  (btr:add-objects-to-mesh-list "cram_knowrob_vr")
  (let ((object-types '(:edeka-red-bowl :koelln-muesli-knusper-honig-nuss
                        :fork-blue-plastic :cup-eco-orange :weide-milch-small)))
    ;; spawn objects at default poses
    (let ((objects (mapcar (lambda (object-type)
                             (btr-utils:spawn-object
                              (intern (format nil "~a2" object-type) :keyword)
                              object-type
                              :color '(1 0 0)))
                           object-types)))
      objects)))

(defun init-location-costmap-parameters ()
  (def-fact-group costmap-metadata ()
    (<- (location-costmap:costmap-size 12 12))
    (<- (location-costmap:costmap-origin -6 -6))
    (<- (location-costmap:costmap-resolution 0.04))

    (<- (location-costmap:costmap-padding 0.3))
    (<- (location-costmap:costmap-manipulation-padding 0.4))
    (<- (location-costmap:costmap-in-reach-distance 0.9))
    (<- (location-costmap:costmap-reach-minimal-distance 0.2))
    (<- (location-costmap:visibility-costmap-size 2))
    (<- (location-costmap:orientation-samples 2))
    (<- (location-costmap:orientation-sample-step 0.1))))

(defun init-full-simulation (&optional namedir)
   "Spawns all the objects which are necessary for the current
scenario (Meaning: Kitchen, Robot, Muesli, Milk, Cup, Bowl, Fork and 3 Axis
objects for debugging."
  (roslisp-utilities:startup-ros)
  (coe:clear-belief)
  (init-episode namedir)
  (spawn-semantic-map)
  (spawn-urdf-items)
  (spawn-semantic-items)
  (init-location-costmap-parameters))


#+currently-using-pr2-pick-place-demo-to-initialize-world
(
 (defun init-bullet-world ()
   "Initializes the bullet world. The robot spawns in the white urdf kitchen,
while the semantic map kitchen is spawned right next to the urdf kitchen,
representing the Virtual Reality world, and how the kitchen was set up there."
   ;; reset bullet world
   (setq btr:*current-bullet-world* nil)

   ;; append own meshes to meshes list so that they can be loaded.
   (btr:add-objects-to-mesh-list "cram_knowrob_vr")

   (setf btr:*mesh-path-whitelist* *mesh-path-whitelist-unreal-kitchen*)

   ;; init tf early. Otherwise there will be exceptions.
   (cram-tf::init-tf)
   (setf cram-tf:*tf-default-timeout* 2.0)
   (setf prolog:*break-on-lisp-errors* t)

   (cram-occupancy-grid-costmap::init-occupancy-grid-costmap)
   (cram-bullet-reasoning-belief-state::ros-time-init)
   (cram-location-costmap::location-costmap-vis-init)

   ;; set costmap parameters
   (prolog:def-fact-group costmap-metadata ()
     (prolog:<- (location-costmap:costmap-size 12 12))
     (prolog:<- (location-costmap:costmap-origin -6 -6))
     (prolog:<- (location-costmap:costmap-resolution 0.05))

     (prolog:<- (location-costmap:costmap-padding 0.2))
     (prolog:<- (location-costmap:costmap-manipulation-padding 0.2))
     (prolog:<- (location-costmap:costmap-in-reach-distance 0.6))
     (prolog:<- (location-costmap:costmap-reach-minimal-distance 0.2)))

;;; initialization from the tutorial
   (prolog:prolog '(and (btr:bullet-world ?world)
                    (assert
                     (btr:object ?world :static-plane :floor ((0 0 0) (0 0 0 1))
                                                      :normal (0 0 1) :constant 0))))
   (prolog:prolog '(and (btr:bullet-world ?world)
                    (btr:debug-window ?world)))

;;; load robot description
   (setf rob-int:*robot-urdf*
         (cl-urdf:parse-urdf
          (roslisp:get-param btr-belief:*robot-parameter*)))
   (prolog:prolog
    `(and (btr:bullet-world ?world)
          (cram-robot-interfaces:robot ?robot)
          (assert (btr:object ?world :urdf ?robot ((0 0 0) (0 0 0 1)) :urdf ,rob-int:*robot-urdf*))
          (rob-int:robot-joint-states ?robot :arm :left :park ?left-joint-states)
          (assert (btr:joint-state ?world ?robot ?left-joint-states))
          (rob-int:robot-joint-states ?robot :arm :right :park ?right-joint-states)
          (assert (btr:joint-state ?world ?robot ?right-joint-states))
          (rob-int:robot-torso-link-joint ?robot ?_ ?torso-joint)
          (rob-int:joint-lower-limit ?robot ?torso-joint ?lower-limit)
          (rob-int:joint-upper-limit ?robot ?torso-joint ?upper-limit)
          (prolog:lisp-fun + ?lower-limit ?upper-limit ?sum)
          (prolog:lisp-fun / ?sum 2.0 ?average-joint-value)
          (assert (btr:joint-state ?world ?robot
                                   ((?torso-joint ?average-joint-value))))))

   (ros-info (kvr) "spawning semantic-map kitchen...")

   (sem-map:get-semantic-map)

   ;; spawning semantic map kitchen
   (prolog:prolog
    `(and (btr:bullet-world ?world)
          (assert (btr:object ?world :semantic-map :semantic-map-kitchen
                              ((0 -3 0) (0 0 0 1))))))

   ;; spawning urdf kitchen
   (prolog:prolog
    `(and (btr:bullet-world ?world)
          (assert (btr:object ?world :urdf :kitchen ((0 0 0) (0 0 0 1))
                                           :collision-group :static-filter
                                           :collision-mask (:default-filter
                                                            :character-filter)
                                           :compound t
                                           :urdf ,(cl-urdf:parse-urdf
                                                   (roslisp:get-param
                                                    "kitchen_description")))))))
 )