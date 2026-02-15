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
    skipping [if_statement]
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
        RuleB   [modifyAction ActionA ActionB]
                [saveToFile]
end rule

rule modifyAction ActionA [action_statement] ActionB [action_statement]
    
    % Get the item and value from Action A
    deconstruct * [item] ActionA
        ActionAItem [item]
    deconstruct * [value] ActionA
        ActionAValue [value]
    
    
    % Create the new Action B
    construct ModifiedActionB [action_statement]
        ActionB [modifyItem ActionAItem]
                [modifyValue ActionAValue]

    export SaveToFile [boolean_literal]
        'false
    
    % Is the modified B value different from the Action A value?
    deconstruct not * [value] ModifiedActionB
        ActionAValue

    % If yes, then perform replacement and save it to file
    export SaveToFile
        'true
    

    skipping [if_statement]
    replace $ [action_statement]
        ActionB
    by
        ModifiedActionB
end rule

rule modifyItem ActionAItem [item]
    replace $ [item]
        _ [item]
    by
        ActionAItem
end rule


rule modifyValue ActionAValue [value]
    replace $ [value]
        ActionBValue [value]

    construct ModifiedActionValue [value]
        ActionBValue    [changeToOFF ActionAValue]
                        [changeToON ActionAValue]
                        [changeToCLOSED ActionAValue]
                        [changeToOPEN ActionAValue]
    by
        ModifiedActionValue
end rule

function changeToOFF ActionAValue [value]
    deconstruct ActionAValue
        ON
    replace [value]
        _ [value]
    by
        OFF
end function

function changeToON ActionAValue [value]
    deconstruct ActionAValue
        OFF
    replace [value]
        _ [value]
    by
        ON
end function

function changeToCLOSED ActionAValue [value]
    deconstruct ActionAValue
        OPEN
    replace [value]
        _ [value]
    by
        CLOSED
end function

function changeToOPEN ActionAValue [value]
    deconstruct ActionAValue
        CLOSED
    replace [value]
        _ [value]
    by
        OPEN
end function


function saveToFile
    import SaveToFile [boolean_literal]
    deconstruct SaveToFile
        'true

    import RuleA [openhab_rule]
    match [openhab_rule]
        RuleB [openhab_rule]

    construct RulesAB [openhab_rule*]
        RuleA
        RuleB
    
    construct FileTitle [id]
        SAC
    
    construct FileId [id]
        FileTitle [!]

    construct FileName [stringlit]
        _ [+ FileId] [+ ".rules"]

    construct _ [openhab_rule*]
        RulesAB [write FileName]

end function