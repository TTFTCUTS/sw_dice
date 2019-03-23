import "dart:math";

import "package:CommonLib/Colours.dart";

import "icons.dart";
import "pool.dart";
import "utility.dart";

class DiceType implements Comparable<DiceType> {
    final String name;
    int order;
    Icon icon = Icon.defaultIcon;

    List<Face> faces = <Face>[];

    Map<SymbolType, double> _stats = null;
    Map<SymbolType, Map<int, int>> _probabilities = <SymbolType, Map<int, int>>{};
    Map<EquatableList<SymbolType>, Map<Map<SymbolType, int>, int>> _compoundProbabilities = <EquatableList<SymbolType>, Map<Map<SymbolType, int>, int>>{};
    Map<EquatableList<SymbolType>, List<Map<Map<SymbolType, int>, int>>> _multiCompoundProbabilities = <EquatableList<SymbolType>, List<Map<Map<SymbolType, int>, int>>>{};

    DiceType(String this.name, {int this.order = 0});

    Face face() {
        Face f = new Face(this);
        faces.add(f);
        return f;
    }

    int get sides => faces.length;

    Face roll(Random rand) {
        if (faces.length == 1) { return faces.first; }

        return faces[rand.nextInt(sides)];
    }

    @override
    String toString() => this.name;

    Map<SymbolType, double> get stats {
        if (_stats == null) {
            _stats = <SymbolType, double>{};

            List<DiceResult> sideResults = (new DicePool()..add(this)).getAllResults();
            DiceResult total = new DiceResult();
            for (DiceResult r in sideResults) {
                for (Face f in r.faces) {
                    total.addFace(f);
                }
            }
            total.tidy();

            for (SymbolType s in total.symbols.keys) {
                _stats[s] = total.symbols[s] / sides;
            }
        }
        return _stats;
    }

    bool relevantToSymbol(SymbolType symbol) {
        if (this.faces.any((Face f) => f.symbols.contains(symbol))) {
            return true;
        }
        if (!symbol.opposed.isEmpty) {
            for (SymbolType o in symbol.opposed) {
                if (this.faces.any((Face f) => f.symbols.contains(o))) {
                    return true;
                }
            }
        }
        return false;
    }

    Map<int,int> getProbabilitiesSingle(SymbolType symbol) {
        if (!_probabilities.containsKey(symbol)) {
            if (!this.relevantToSymbol(symbol)) {
                // no faces on this dice have this symbol, so set to null
                _probabilities[symbol] = null;
            } else {
                // at least one face has this symbol, so determine weights
                Map<int,int> weights = <int,int>{};

                for (Face f in this.faces) {
                    int count = 0;
                    for (SymbolType s in f.symbols) {
                        if (s == symbol) {
                            count++;
                        } else if (symbol.opposed.contains(s)) {
                            count--;
                        }

                        for (SymbolType ad in s.additional) {
                            if (ad == symbol) {
                                count++;
                            } else if (symbol.opposed.contains(ad)) {
                                count--;
                            }
                        }
                    }
                    if (!weights.containsKey(count)) {
                        weights[count] = 1;
                    } else {
                        weights[count] = weights[count] + 1;
                    }
                }
                _probabilities[symbol] = weights;
            }
            //print("$name: calculating weight for $symbol");
        } //else {
            //print("$name: short circuit for $symbol");
        //}
        return _probabilities[symbol];
    }

    Map<Map<SymbolType, int>, int> getCompoundProbabilities(EquatableList<SymbolType> symbols) {
        if (!_compoundProbabilities.containsKey(symbols)) {
            bool relevant = false;
            for (SymbolType s in symbols) {
                if (relevantToSymbol(s)) {
                    relevant = true;
                    break;
                }
            }
            if (!relevant) {
                // not relevant to any of the symbols, so set to null
                _compoundProbabilities[symbols] = null;
            } else {
                Map<Map<SymbolType, int>, int> weights = <Map<SymbolType, int>, int>{};

                for(Face f in this.faces) {
                    Map<SymbolType, int> counts = new SymbolMap();
                    //Map<SymbolType, int> counts = new EquatableMap<SymbolType, int>();
                    for (SymbolType s in symbols) {
                        counts[s] = 0;
                    }

                    for (SymbolType s in f.symbols) {
                        for (SymbolType symbol in symbols) {
                            if (s == symbol) {
                                counts[symbol]++;
                            } else if (symbol.opposed.contains(s)) {
                                counts[symbol]--;
                            }

                            for (SymbolType ad in s.additional) {
                                if (ad == symbol) {
                                    counts[symbol]++;
                                } else if (symbol.opposed.contains(ad)) {
                                    counts[symbol]--;
                                }
                            }
                        }
                    }

                    //print("$counts ${counts.hashCode} ${counts.hashCode.toRadixString(2)}");

                    if (!weights.containsKey(counts)) {
                        weights[counts] = 1;
                    } else {
                        weights[counts] = weights[counts] + 1;
                    }
                }

                _compoundProbabilities[symbols] = weights;
            }
            //print("$name: calculating compound weight for $symbols, ${_compoundProbabilities[symbols]}");
        } //else {
            //print("$name: compound short circuit for $symbols");
        //}
        return _compoundProbabilities[symbols];
    }

    Map<Map<SymbolType, int>, int> getProbabilities({List<SymbolType> symbolTypes = null, int count = 1}) {
        EquatableList<SymbolType> symbols = new EquatableList<SymbolType>();

        symbolTypes ??= Dice.ALL_SYMBOLS;
        symbols.addAll(symbolTypes);

        Map<Map<SymbolType, int>, int> results = <Map<SymbolType, int>, int>{};

        int remainingCount = count;

        if (_multiCompoundProbabilities[symbols] == null) {
            _multiCompoundProbabilities[symbols] = <Map<Map<SymbolType, int>, int>>[
                getCompoundProbabilities(symbols) // position 0 is 1 die, 1 is 2 dice etc
            ];
        }
        List<Map<Map<SymbolType, int>, int>> probs = _multiCompoundProbabilities[symbols];
        int iter = 0;
        int total = 0;

        if (probs.length >= remainingCount && probs[remainingCount-1] != null) {
            results.addAll(probs[remainingCount-1]);
        } else {
            while (remainingCount > 0 && iter < 1000000) {
                iter++;
                int largest = min(remainingCount, probs.length);

                // find the largest existing dataset that is within the remaining count
                int selected;
                for (int i = largest - 1; i >= 0; i--) {
                    if (probs[i] != null) {
                        selected = i;
                        break;
                    }
                }
                remainingCount -= selected + 1;
                total += selected + 1;

                // use the retrieved dataset
                Map<Map<SymbolType, int>, int> data = probs[selected];

                if (results.isEmpty) {
                    results.addAll(data);
                } else {
                    results = DiceType.combineCompoundProbabilities(results, data);
                }

                // add current results if that length isn't present
                if (probs.length <= total) {
                    probs.length = total;
                }
                if (probs[total - 1] == null) {
                    probs[total - 1] = <Map<SymbolType, int>, int>{}..addAll(results);
                }
            }
        }

        return results;
    }

    @override
    int compareTo(DiceType other) => this.order.compareTo(other.order);

    // probability structure is a map of face configurations vs face counts
    // {
    //   {success: 1, advantage: 0} : 1
    // }
    // etc
    static Map<Map<SymbolType, int>, int> combineCompoundProbabilities(Map<Map<SymbolType, int>, int> first, Map<Map<SymbolType, int>, int> second) {
        Map<Map<SymbolType, int>, int> totals = <Map<SymbolType, int>,int>{};

        for(Map<SymbolType, int> ocFirst in first.keys) {
            int countFirst = first[ocFirst];

            for(Map<SymbolType, int> ocSecond in second.keys) {
                int countSecond = second[ocSecond];

                Map<SymbolType, int> outcome = new SymbolMap();
                //Map<SymbolType, int> outcome = new EquatableMap<SymbolType, int>();

                // construct new face
                for (SymbolType symbol in ocFirst.keys) {
                    if (!outcome.containsKey(symbol)) {
                        outcome[symbol] = ocFirst[symbol];
                    } else {
                        outcome[symbol] = outcome[symbol] + ocFirst[symbol];
                    }
                }
                for (SymbolType symbol in ocSecond.keys) {
                    if (!outcome.containsKey(symbol)) {
                        outcome[symbol] = ocSecond[symbol];
                    } else {
                        outcome[symbol] = outcome[symbol] + ocSecond[symbol];
                    }
                }

                // add it to the new probability table
                if (!totals.containsKey(outcome)) {
                    totals[outcome] = countFirst * countSecond;
                } else {
                    totals[outcome] = totals[outcome] + countFirst * countSecond;
                }
            }
        }

        /*int firstSides = 0;
        for (int n in first.values) { firstSides += n; }
        int secondSides = 0;
        for (int n in second.values) { secondSides += n; }
        int totalSides = 0;
        for (int n in totals.values) { totalSides += n; }
        print("first: $firstSides, second: $secondSides, total: $totalSides");*/

        return totals;
    }
}

class Face {
    final DiceType dice;
    List<SymbolType> symbols = <SymbolType>[];
    Icon _icon;

    Face(DiceType this.dice);

    Face symbol(SymbolType s) {
        symbols.add(s);
        return this;
    }

    Icon get icon {
        if (_icon == null) {
            _icon = dice.icon;
        }
        return _icon;
    }

    @override
    String toString() => "$dice:$symbols";
}

class SymbolType {
    final String name;
    Set<SymbolType> opposed = new Set<SymbolType>();
    List<SymbolType> additional = <SymbolType>[];
    Icon icon = Icon.defaultIcon;

    SymbolType(String this.name);

    void opposes(SymbolType symbol) {
        opposed.add(symbol);
        symbol.opposed.add(this);
    }

    void also(SymbolType symbol) => additional.add(symbol);

    @override
    String toString() => name;
}

abstract class Dice {
    static final SymbolType SUCCESS   = new SymbolType("Success")
        ..icon=new LayeredTextIcon().layer("s");
    static final SymbolType FAILURE   = new SymbolType("Failure")..opposes(SUCCESS)
        ..icon=new LayeredTextIcon().layer("f");
    static final SymbolType ADVANTAGE = new SymbolType("Advantage")
        ..icon=new LayeredTextIcon().layer("a");
    static final SymbolType THREAT    = new SymbolType("Threat")..opposes(ADVANTAGE)
        ..icon=new LayeredTextIcon().layer("t");
    static final SymbolType TRIUMPH   = new SymbolType("Triumph")..also(SUCCESS)
        ..icon=new LayeredTextIcon().layer("x");
    static final SymbolType DESPAIR   = new SymbolType("Despair")..also(FAILURE)
        ..icon=new LayeredTextIcon().layer("y");
    static final SymbolType LIGHTSIDE = new SymbolType("Light Side Force Point")
        ..icon=new LayeredTextIcon().layer("z", new Colour.fromHex(0xFFFFFF)).layer("Z");
    static final SymbolType DARKSIDE  = new SymbolType("Dark Side Force Point")
        ..icon=new LayeredTextIcon().layer("z").layer("Z");

    static final EquatableList<SymbolType> ALL_SYMBOLS = new EquatableList<SymbolType>()..addAll(<SymbolType>[
        SUCCESS,
        FAILURE,
        ADVANTAGE,
        THREAT,
        TRIUMPH,
        DESPAIR,
        LIGHTSIDE,
        DARKSIDE,
    ]);
    static final Map<String, SymbolType> SYMBOLS_BY_NAME = new Map<String, SymbolType>.fromIterable(ALL_SYMBOLS, key: (dynamic s) => s.name, value: (dynamic s) => s);

    static final DiceType BOOST = new DiceType("Boost", order: 0)
        ..icon=new LayeredTextIcon().layer("b", new Colour.fromHex(0xBBDDFF)).layer("B")
        ..face()
        ..face()
        ..face().symbol(SUCCESS)
        ..face().symbol(SUCCESS).symbol(ADVANTAGE)
        ..face().symbol(ADVANTAGE)
        ..face().symbol(ADVANTAGE).symbol(ADVANTAGE);

    static final DiceType SETBACK = new DiceType("Setback", order:5)
        ..icon=new LayeredTextIcon().layer("b", new Colour.fromHex(0x202020)).layer("B")
        ..face()
        ..face()
        ..face().symbol(FAILURE)
        ..face().symbol(FAILURE)
        ..face().symbol(THREAT)
        ..face().symbol(THREAT);

    static final DiceType ABILITY = new DiceType("Ability", order: 1)
        ..icon=new LayeredTextIcon().layer("d", new Colour.fromHex(0x11AA11)).layer("D")
        ..face()
        ..face().symbol(SUCCESS)
        ..face().symbol(SUCCESS)
        ..face().symbol(ADVANTAGE)
        ..face().symbol(ADVANTAGE)
        ..face().symbol(SUCCESS).symbol(ADVANTAGE)
        ..face().symbol(SUCCESS).symbol(SUCCESS)
        ..face().symbol(ADVANTAGE).symbol(ADVANTAGE);

    static final DiceType DIFFICULTY = new DiceType("Difficulty", order: 3)
        ..icon=new LayeredTextIcon().layer("d", new Colour.fromHex(0x8000DD)).layer("D")
        ..face()
        ..face().symbol(FAILURE)
        ..face().symbol(THREAT)
        ..face().symbol(THREAT)
        ..face().symbol(THREAT)
        ..face().symbol(FAILURE).symbol(THREAT)
        ..face().symbol(FAILURE).symbol(FAILURE)
        ..face().symbol(THREAT).symbol(THREAT);

    static final DiceType PROFICIENCY = new DiceType("Proficiency", order: 2)
        ..icon=new LayeredTextIcon().layer("c", new Colour.fromHex(0xFFF611)).layer("C")
        ..face()
        ..face().symbol(SUCCESS)
        ..face().symbol(SUCCESS)
        ..face().symbol(SUCCESS).symbol(SUCCESS)
        ..face().symbol(SUCCESS).symbol(SUCCESS)
        ..face().symbol(ADVANTAGE)
        ..face().symbol(ADVANTAGE).symbol(ADVANTAGE)
        ..face().symbol(ADVANTAGE).symbol(ADVANTAGE)
        ..face().symbol(SUCCESS).symbol(ADVANTAGE)
        ..face().symbol(SUCCESS).symbol(ADVANTAGE)
        ..face().symbol(SUCCESS).symbol(ADVANTAGE)
        ..face().symbol(TRIUMPH);

    static final DiceType CHALLENGE = new DiceType("Challenge", order: 4)
        ..icon=new LayeredTextIcon().layer("c", new Colour.fromHex(0xDD1111)).layer("C")
        ..face()
        ..face().symbol(FAILURE)
        ..face().symbol(FAILURE)
        ..face().symbol(FAILURE).symbol(FAILURE)
        ..face().symbol(FAILURE).symbol(FAILURE)
        ..face().symbol(THREAT)
        ..face().symbol(THREAT)
        ..face().symbol(THREAT).symbol(THREAT)
        ..face().symbol(THREAT).symbol(THREAT)
        ..face().symbol(FAILURE).symbol(THREAT)
        ..face().symbol(FAILURE).symbol(THREAT)
        ..face().symbol(DESPAIR);

    static final DiceType FORCE = new DiceType("Force", order: 6)
        ..icon=new LayeredTextIcon().layer("c", new Colour.fromHex(0xFFFFFF)).layer("C")
        ..face().symbol(LIGHTSIDE).symbol(LIGHTSIDE)
        ..face().symbol(LIGHTSIDE).symbol(LIGHTSIDE)
        ..face().symbol(LIGHTSIDE).symbol(LIGHTSIDE)
        ..face().symbol(LIGHTSIDE)
        ..face().symbol(LIGHTSIDE)
        ..face().symbol(DARKSIDE).symbol(DARKSIDE)
        ..face().symbol(DARKSIDE)
        ..face().symbol(DARKSIDE)
        ..face().symbol(DARKSIDE)
        ..face().symbol(DARKSIDE)
        ..face().symbol(DARKSIDE)
        ..face().symbol(DARKSIDE);

    static final EquatableList<DiceType> ALL_DICE = new EquatableList<DiceType>()..addAll(<DiceType>[
        BOOST,
        SETBACK,
        ABILITY,
        DIFFICULTY,
        PROFICIENCY,
        CHALLENGE,
        FORCE,
    ]);
    static final Map<String, SymbolType> DICE_BY_NAME = new Map<String, SymbolType>.fromIterable(ALL_DICE, key: (dynamic d) => d.name, value: (dynamic d) => d);
}