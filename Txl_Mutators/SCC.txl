include "../Grammars/java.grm"
include "../Grammars/openhab.grm"

function main
    replace [program]
        P   [program]
    by
        P   [processRules]
end function

function processRules
    match * [repeat openhab_rule]
        Rules [repeat openhab_rule]

    deconstruct Rules
        RuleA [openhab_rule]
        OldRuleB [openhab_rule]
        RestRest [repeat openhab_rule]

    construct RuleB [openhab_rule]
        OldRuleB [ensureCompatibleTriggers RuleA]

    export RuleA
    export RuleB

    construct _ [openhab_rule]
        RuleA [iterateActionsA RuleB]
end function



%%%%%
% TRIGGER FUNCTIONS
%%%%%
function ensureCompatibleTriggers RuleA [openhab_rule]
    deconstruct * [triggers] RuleA
        FirstTriggerA [trigger] RestTriggersA [repeat more_triggers]
    
    replace * [triggers]
        FirstTriggerB [trigger] RestTriggersB [repeat more_triggers]

    construct TriggerListA [repeat trigger]
        _   [. FirstTriggerA] 
            [extractMoreTriggers each RestTriggersA]
    construct TriggerListB [repeat trigger]
        _   [. FirstTriggerB] 
            [extractMoreTriggers each RestTriggersB]

    export FoundCompatibleTrigger [boolean_literal]
        'false
    construct _ [repeat trigger]
        TriggerListA [findCompatibleTrigger each TriggerListB]

    % If a compatible trigger pair is found, exit
    % If not, replace with an identical trigger
    import FoundCompatibleTrigger
    deconstruct FoundCompatibleTrigger
        'false
    by
        FirstTriggerA
        RestTriggersB
end function

rule findCompatibleTrigger TriggerB [trigger]   
    match $ [trigger]
        TriggerA [trigger]

    construct _ [trigger]
        TriggerB    [checkTriggerTypeCompatibility TriggerA]
                    [checkTriggerItemCompatibility TriggerA]
                    [checkTriggerValueCompatibility TriggerA]

end rule

rule checkTriggerTypeCompatibility TriggerA [trigger]
    match [trigger]
        TriggerB [trigger]

    % Are the triggers the same type?
    deconstruct * [trigger_type] TriggerA
        TriggerType [trigger_type]
    deconstruct not * [trigger_type] TriggerB
        TriggerType

    % If not, compatible
    export FoundCompatibleTrigger [boolean_literal]
        'true
end rule

rule checkTriggerItemCompatibility TriggerA [trigger]
    match [trigger]
        TriggerB [trigger]

    % Are the triggers the same type?
    deconstruct * [trigger_type] TriggerA
        TriggerType [trigger_type]
    deconstruct * [trigger_type] TriggerB
        TriggerType

    % If yes, do they monitor the same item?
    deconstruct * [item] TriggerA
        Item [item]
    deconstruct not * [item] TriggerB
        Item

    % If not, compatible
    export FoundCompatibleTrigger [boolean_literal]
        'true
end rule

rule checkTriggerValueCompatibility TriggerA [trigger]
    match [trigger]
        TriggerB [trigger]

    % Are the triggers the same type?
    deconstruct * [trigger_type] TriggerA
        TriggerType [trigger_type]
    deconstruct * [trigger_type] TriggerB
        TriggerType

    % If yes, do they monitor the same item?
    deconstruct * [item] TriggerA
        Item [item]
    deconstruct * [item] TriggerB
        Item

    % If yes, are they monitoring for compatible values?
    skipping [opt from_value]
    deconstruct * [value] TriggerA
        Value [value]
    skipping [opt from_value]
    deconstruct * [value] TriggerB
        Value

    % If yes, compatible
    export FoundCompatibleTrigger [boolean_literal]
        'true
end rule

function extractMoreTriggers NextTC [more_triggers]
    deconstruct NextTC
        'or NextTrigger [trigger]
    replace [repeat trigger]
        TriggerList [repeat trigger]
    by
        TriggerList [. NextTrigger]
end function




%%%%%
% ACTION FUNCTIONS
%%%%%
rule iterateActionsA RuleB [openhab_rule]
    match $ [action_statement]
        ActionA [action_statement]

    construct _ [openhab_rule]
        RuleB [iterateActionsB ActionA]
end rule

rule iterateActionsB ActionA [action_statement]
    skipping [if_statement]
    match $ [action_statement]
        ActionB [action_statement]

    import RuleB [openhab_rule]
    
    construct _ [openhab_rule]
        RuleB   [insertCondition ActionA ActionB]
                [saveToFile]
end rule

rule insertCondition ActionA [action_statement] ActionB [action_statement]
    
    % Get the item and value from Action A
    deconstruct * [item] ActionA
        ActionAItem [item]
    deconstruct * [value] ActionA
        ActionAValue [value]

    deconstruct ActionAItem
        ItemA [id]
    deconstruct ActionAValue
        ValueA [relational_expression]

    construct E [expression]
        ItemA .state == ValueA

    construct IfStatement [if_statement]
        'if '( ItemA .state == ValueA ')
            ActionB

    skipping [if_statement]
    replace $ [statement]
        ActionB
    by
        IfStatement
end rule



function saveToFile
    import RuleA [openhab_rule]
    match [openhab_rule]
        RuleB [openhab_rule]

    construct RulesAB [openhab_rule*]
        RuleA
        RuleB
    
    construct FileTitle [id]
        SCC
    
    construct FileId [id]
        FileTitle [!]

    construct FileName [stringlit]
        _ [+ FileId] [+ ".rules"]

    construct _ [openhab_rule*]
        RulesAB [write FileName]

end function