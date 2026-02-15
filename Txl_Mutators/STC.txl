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
        RuleB [openhab_rule]
        RestRest [repeat openhab_rule]

    export RuleA
    export RuleB

    construct _ [openhab_rule]
        RuleA [iterateActionsA RuleB]
end function


rule iterateActionsA RuleB [openhab_rule]
    skipping [if_statement]
    match $ [action_statement]
        ActionA [action_statement]

    construct _ [openhab_rule]
        RuleB   [iterateTriggers ActionA RuleB]
end rule

rule iterateTriggers ActionA [action_statement] RuleB [openhab_rule]
    match $ [trigger]
        Trigger [trigger]

    construct _ [openhab_rule]
        RuleB   [replaceTrigger Trigger ActionA]
                [findOneAction]
                [SaveToFile]

end rule

function findOneAction
    import SaveToFile [boolean_literal]
    deconstruct SaveToFile
        'true

    export SaveToFile
        'false

    skipping [if_statement]
    match * [action_statement]
        _ [action_statement]

    export SaveToFile
        'true
    
end function



function replaceTrigger Trigger [trigger] ActionA [action_statement]
    deconstruct * [item] ActionA
        ActionItem [item]
    deconstruct * [value] ActionA
        ActionValue [value]

    replace * [trigger]
        Trigger
    
    export SaveToFile [boolean_literal]
        'false
    construct NewTrigger [trigger]
        Trigger [replaceItemAndValueUpCom ActionItem ActionValue]
                [replaceItemAndValueCh ActionItem ActionValue]
                [replaceItemUpCom ActionItem]
                [replaceItemCh ActionItem]
                [replaceWholeTrigger ActionItem ActionValue] 
    by
        NewTrigger
end function



function replaceItemAndValueUpCom ActionItem [item] ActionValue [value]
    deconstruct ActionValue
        ValueId [id]
    where
        ValueId [= "ON"] [= "OFF"] [= "OPEN"] [= "CLOSED"]
        
    
    replace [trigger]
        'Item _ [item] ChangeType [change_type] _ [value]
    export SaveToFile [boolean_literal]
        'true
    by
        'Item ActionItem ChangeType ActionValue
end function

function replaceItemAndValueCh ActionItem [item] ActionValue [value]
    deconstruct ActionValue
        ValueId [id]
    where
        ValueId [= "ON"] [= "OFF"] [= "OPEN"] [= "CLOSED"]
        
    replace [trigger]
        'Item _ [item] ChangeType [change_type] _ [opt from_value] _ [to_value]
    export SaveToFile [boolean_literal]
        'true
    by
        'Item ActionItem ChangeType 'to ActionValue
end function



function replaceItemUpCom ActionItem [item]
    replace [trigger]
        'Item _ [item] ChangeType [change_type] _ [opt value]
    export SaveToFile [boolean_literal]
        'true
    by
        'Item ActionItem ChangeType
end function

function replaceItemCh ActionItem [item]
    replace [trigger]
        'Item _ [item] ChangeType [change_type] _ [opt from_value] _ [opt to_value]
    export SaveToFile [boolean_literal]
        'true
    by
        'Item ActionItem ChangeType
end function



function replaceWholeTrigger ActionItem [item] ActionValue [value]
    replace [trigger]
        T [trigger]
    deconstruct not * [trigger_type] T
        'Item
    export SaveToFile [boolean_literal]
        'true
    by
        'Item ActionItem 'changed
end function




function SaveToFile
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
        STC
    
    construct FileId [id]
        FileTitle [!]

    construct FileName [stringlit]
        _ [+ FileId] [+ ".rules"]

    construct _ [openhab_rule*]
        RulesAB [write FileName]

end function
