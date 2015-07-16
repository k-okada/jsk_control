// -*- mode: c++ -*-
/*********************************************************************
 * Software License Agreement (BSD License)
 *
 *  Copyright (c) 2015, JSK Lab
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above
 *     copyright notice, this list of conditions and the following
 *     disclaimer in the documentation and/o2r other materials provided
 *     with the distribution.
 *   * Neither the name of the JSK Lab nor the names of its
 *     contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 *  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *********************************************************************/


#ifndef JSK_FOOTSTEP_PLANNER_FOOTSTEP_GRAPH_H_
#define JSK_FOOTSTEP_PLANNER_FOOTSTEP_GRAPH_H_
#include <ros/ros.h>
#include <jsk_footstep_msgs/FootstepArray.h>

#include "jsk_footstep_planner/graph.h"
#include "jsk_footstep_planner/footstep_state.h"
#include "jsk_footstep_planner/astar_solver.h"

namespace jsk_footstep_planner
{
  class FootstepGraph: public Graph<FootstepState>
  {
  public:
    typedef boost::shared_ptr<FootstepGraph> Ptr;
    FootstepGraph(const Eigen::Vector3f& resolution):
      max_successor_distance_(0.0), max_successor_rotation_(0.0),
      pos_goal_thr_(0.1), rot_goal_thr_(0.17), publish_progress_(false),
      resolution_(resolution) {}
    virtual std::vector<StatePtr> successors(StatePtr target_state);
    virtual bool isGoal(StatePtr state);
    virtual void setBasicSuccessors(
      std::vector<Eigen::Affine3f> left_to_right_successors);
    
    virtual void setGoalState(
      FootstepState::Ptr left, FootstepState::Ptr right)
    {
      left_goal_state_ = left;
      right_goal_state_ = right;
    }

    virtual FootstepState::Ptr getGoal(int leg)
    {
      if (leg == jsk_footstep_msgs::Footstep::LEFT) {
        return left_goal_state_;
      }
      else if (leg == jsk_footstep_msgs::Footstep::RIGHT) {
        return right_goal_state_;
      }
      else {                    // TODO: error
        return goal_state_;
      }
    }

    virtual double maxSuccessorDistance()
    {
      return max_successor_distance_;
    }
    virtual double maxSuccessorRotation()
    {
      return max_successor_rotation_;
    }

    virtual void setProgressPublisher(ros::NodeHandle& nh, std::string topic)
    {
      publish_progress_ = true;
      pub_progress_ = nh.advertise<jsk_footstep_msgs::FootstepArray>(topic, 1);
    }
    
  protected:
    std::vector<Eigen::Affine3f> successors_from_left_to_right_;
    std::vector<Eigen::Affine3f> successors_from_right_to_left_;
    FootstepState::Ptr left_goal_state_;
    FootstepState::Ptr right_goal_state_;
    double max_successor_distance_;
    double max_successor_rotation_;
    double pos_goal_thr_;
    double rot_goal_thr_;
    bool publish_progress_;
    ros::Publisher pub_progress_;
    const Eigen::Vector3f resolution_;
  private:

  };

  // heuristic function
  double footstepHeuristicZero(
    SolverNode<FootstepState, FootstepGraph>::Ptr node, FootstepGraph::Ptr graph);
  double footstepHeuristicStraight(
    SolverNode<FootstepState, FootstepGraph>::Ptr node, FootstepGraph::Ptr graph);
  double footstepHeuristicStraightRotation(
    SolverNode<FootstepState, FootstepGraph>::Ptr node, FootstepGraph::Ptr graph);
  double footstepHeuristicStepCost(
    SolverNode<FootstepState, FootstepGraph>::Ptr node, FootstepGraph::Ptr graph);
}

#endif