# Assignments
assignment_stat = AssignmentStat.new
rule = NoLateSubmissionRule.new
a = Assignment.create(:short_identifier => "A1",
                      :description => "Conditionals and Loops",
                      :message => "Learn to use conditional statements, and loops.",
                      :group_min => 1,
                      :group_max => 1,
                      :student_form_groups => false,
                      :group_name_autogenerated => true,
                      :group_name_displayed => false,
                      :repository_folder => "A1",
                      :due_date => 1.minute.from_now,
                      :marking_scheme_type => Assignment::MARKING_SCHEME_TYPE[:rubric],
                      :allow_web_submits => true,
                      :display_grader_names_to_students => false)

a.submission_rule = rule
a.assignment_stat = assignment_stat
a.save

rule = NoLateSubmissionRule.new
assignment_stat = AssignmentStat.new
a = Assignment.create(:short_identifier => "A2",
                      :description => "Cats and Dogs",
                      :message => "Basic exercise in Object Oriented
                      Programming.  Implement Animal, Cat, and Dog, as
                      described in class.",
                      :group_min => 2,
                      :group_max => 3,
                      :student_form_groups => true,
                      :group_name_autogenerated => true,
                      :group_name_displayed => false,
                      :repository_folder => "A2",
                      :due_date => 1.month.from_now,
                      :marking_scheme_type => Assignment::MARKING_SCHEME_TYPE[:rubric],
                      :allow_web_submits => true,
                      :display_grader_names_to_students => false)
a.submission_rule = rule
a.assignment_stat = assignment_stat
a.save
