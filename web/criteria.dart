import "dart:html";

import "dice.dart";
import "pool.dart";

abstract class C {
    static Criterion not(Criterion criterion) => new NotCriterion()..add(criterion);

    static Criterion allOf(Criterion a, Criterion b, [Criterion c, Criterion d, Criterion e, Criterion f]) {
        return new AndCriterion()..add(a)..add(b)..add(c)..add(d)..add(e)..add(f);
    }
    static Criterion notAllOf(Criterion a, Criterion b, [Criterion c, Criterion d, Criterion e, Criterion f]) {
        return not(new AndCriterion()..add(a)..add(b)..add(c)..add(d)..add(e)..add(f));
    }

    static Criterion anyOf(Criterion a, Criterion b, [Criterion c, Criterion d, Criterion e, Criterion f]) {
        return new OrCriterion()..add(a)..add(b)..add(c)..add(d)..add(e)..add(f);
    }
    static Criterion noneOf(Criterion a, Criterion b, [Criterion c, Criterion d, Criterion e, Criterion f]) {
        return not(new OrCriterion()..add(a)..add(b)..add(c)..add(d)..add(e)..add(f));
    }

    static Criterion oneOf(Criterion a, Criterion b, [Criterion c, Criterion d, Criterion e, Criterion f]) {
        return new XorCriterion()..add(a)..add(b)..add(c)..add(d)..add(e)..add(f);
    }

    static Criterion compare(SymbolType symbol, Comparison comparison, int number) => new ComparisonCriterion(symbol, comparison, number);
}

abstract class Criterion {
    Criterion parent;

    bool evaluate(Map<SymbolType, int> face);
    void add(Criterion criterion);
    void remove(Criterion criterion);

}

abstract class ComboCriterion extends Criterion {
    List<Criterion> criteria = <Criterion>[];

    void add(Criterion other) {
        if (other == null) { return; }
        criteria.add(other);
        other.parent = this;
    }

    void remove(Criterion other) {
        criteria.remove(other);
    }
}

class AndCriterion extends ComboCriterion {
    bool evaluate(Map<SymbolType, int> face) {
        for (Criterion c in criteria) {
            if (!c.evaluate(face)) {
                return false;
            }
        }
        return true;
    }
}

class OrCriterion extends ComboCriterion {
    bool evaluate(Map<SymbolType, int> face) {
        for (Criterion c in criteria) {
            if (c.evaluate(face)) {
                return true;
            }
        }
        return false;
    }
}

class NotCriterion extends Criterion {
    Criterion inverse;
    Element inverseContainer;

    bool evaluate(Map<SymbolType, int> face) => !inverse.evaluate(face);

    void add(Criterion criterion) {
        this.inverse = criterion;
        criterion.parent = this;
    }
    void remove(Criterion criterion) {
        if (this.inverse == criterion) {
            this.inverse = null;
            criterion.parent = null;
        }
    }
}

class XorCriterion extends ComboCriterion {
    bool evaluate(Map<SymbolType, int> face) {
        int successes = 0;
        for (Criterion c in criteria) {
            if (c.evaluate(face)) {
                successes++;
            }
            if (successes > 1) {
                return false;
            }
        }
        return successes == 1;
    }
}

class ComparisonCriterion extends DicePoolComparisonCriterion with Criterion {

    ComparisonCriterion(SymbolType symbol, Comparison comparison, int number):super(symbol, comparison, number) {}

    bool evaluate(Map<SymbolType, int> face) {
        if (!face.containsKey(symbol)) { return false; }
        return comparison.function(face[symbol], number);
    }

    // no-ops
    void add(Criterion other){}
    void remove(Criterion other){}
}

// old comparison functions

typedef bool ComparisonFunction(int a, int b);
class Comparison {
    static final Comparison EQUAL                   = new Comparison._("exactly",  (int a, int b) => a == b);
    static final Comparison GREATER_THAN            = new Comparison._("more than",  (int a, int b) => a >  b);
    static final Comparison GREATER_THAN_OR_EQUAL   = new Comparison._("at least", (int a, int b) => a >= b);
    static final Comparison LESS_THAN               = new Comparison._("fewer than",  (int a, int b) => a <  b);
    static final Comparison LESS_THAN_OR_EQUAL      = new Comparison._("at most", (int a, int b) => a <= b);

    static final List<Comparison> values = new List<Comparison>.unmodifiable(<Comparison>[
        GREATER_THAN_OR_EQUAL,
        LESS_THAN_OR_EQUAL,
        GREATER_THAN,
        LESS_THAN,
        EQUAL,
    ]);
    static final Map<String, Comparison> byName = new Map<String, Comparison>.fromIterable(values, key: (dynamic c) => c.text, value: (dynamic c) => c);

    final ComparisonFunction function;
    final String text;
    Comparison._(String this.text, ComparisonFunction this.function){}
}

class DicePoolComparisonCriterion {
    SymbolType symbol;
    Comparison comparison;
    int number;
    DicePoolComparisonCriterion(SymbolType this.symbol, Comparison this.comparison, int this.number){}
}

// UI stuff

class CriterionSelectorUI {
    static const List<List<String>> uiTypes = <List<String>>[
        <String>["compare", "Comparison"],
        <String>["not", "Not"],
        <String>["and", "All of"],
        <String>["or", "Any of"],
    ];

    Element element;
    SelectElement selector;
    Element container;

    CriterionBlockUI block;

    final bool removable;
    Element removeButton;

    CriterionSelectorUI([bool this.removable = false]) {
        Element e = new DivElement()..className="condition";

        container = new DivElement();

        if (removable) {
            removeButton = new DivElement()
                //..text="\u00D7"
                ..text = "-"
                ..className="removeButton";
            e.append(removeButton);
        }

        selector = new SelectElement();

        for (List<String> info in uiTypes) {
            OptionElement o = new OptionElement(value: info[0])..text=info[1];
            selector.append(o);
        }

        e.append(selector);
        e.append(container);

        selector.onChange.listen((Event e){
            OptionElement selected = selector.options[selector.selectedIndex];
            this.setBlock(new CriterionBlockUI(selected.value, selected.text));
        });

        this.element = e;

        this.setBlock(new CriterionBlockUI(selector.options.first.value, selector.options.first.text));
    }

    void setBlock(CriterionBlockUI b) {
        this.container.children.clear();
        this.block = b;
        this.container.append(b.element);
    }

    Criterion buildCriterion() {
        return this.block.buildCriterion();
    }
}

class CriterionBlockUI {
    Element element;

    final String type;
    List<CriterionSelectorUI> subSections;
    Element subContainer;

    // comparison specific
    SelectElement symbolSelector;
    SelectElement comparisonSelector;
    NumberInputElement numberSelector;

    CriterionBlockUI(String this.type, String label) {
        this.element = new DivElement();

        //element.append(new DivElement()..text=label);

        if (type == "compare") {
            this.element.className="conditionSelector";

            SelectElement symbol = new SelectElement()..className="conditionSelectorSymbol";
            for (SymbolType s in Dice.ALL_SYMBOLS) {
                symbol.append(new OptionElement(value: s.name, data: s.name));
            }
            element.append(symbol);
            symbolSelector = symbol;

            SelectElement comparison = new SelectElement()..className="conditionSelectorComparison";
            for (Comparison c in Comparison.values) {
                comparison.append(new OptionElement(value: c.text, data: c.text));
            }
            element.append(comparison);
            comparisonSelector = comparison;

            NumberInputElement number = new NumberInputElement()
                ..className="conditionSelectorNumber"
                ..valueAsNumber = 1
                ..min = "0"
            ;
            element.append(number);
            numberSelector = number;
        } else if (type == "not") {
            subSections = <CriterionSelectorUI>[];
            subContainer = new DivElement()..className="conditionContainer";
            element.append(subContainer);

            this.addSubSection(false);
        } else {
            subSections = <CriterionSelectorUI>[];
            subContainer = new DivElement()..className="conditionContainer";
            element.append(subContainer);

            this.addSubSection(false);
            this.addSubSection(false);

            Element addButton = new DivElement()..text="+"..className="addButton";
            element.append(addButton);
            addButton.onClick.listen((MouseEvent e) {
                this.addSubSection(true);
            });
        }
    }

    void addSubSection(bool removable) {
        CriterionSelectorUI selector = new CriterionSelectorUI(removable);
        subSections.add(selector);
        subContainer.append(selector.element);
        if (removable) {
            selector.removeButton.onClick.listen((MouseEvent e) {
                subSections.remove(selector);
                selector.element.remove();
            });
        }
    }

    Criterion buildCriterion() {
        if (type == "compare") {
            return new ComparisonCriterion(Dice.SYMBOLS_BY_NAME[symbolSelector.value], Comparison.byName[comparisonSelector.value], numberSelector.valueAsNumber);
        } else if (type == "not") {
            return new NotCriterion()..add(subSections.first.buildCriterion());
        } else {
            ComboCriterion criterion;

            if (type == "and") {
                criterion = new AndCriterion();
            } else if (type == "or") {
                criterion = new OrCriterion();
            }

            for (CriterionSelectorUI subsection in this.subSections) {
                criterion.add(subsection.buildCriterion());
            }
            return criterion;
        }
    }
}