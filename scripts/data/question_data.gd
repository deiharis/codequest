extends Resource
class_name QuestionData
## One multiple-choice question.
##
## Authored in data/questions.csv and built at runtime by QuestionBank. These
## are not saved as .tres — 60 question files would be 60 things to keep in
## sync, and a spreadsheet is a better editor for content than the Inspector.

@export var question_text: String = ""
@export var options: Array[String] = []
@export var correct_option_index: int = 0
## Seconds allowed for this question in timed fights. Computed from the
## question's length by QuestionBank unless the CSV overrides it.
@export var time_limit: float = 15.0
## Shown after answering. This is the teaching moment — the question tests,
## the explanation is what the player actually takes away.
@export var explanation: String = ""
