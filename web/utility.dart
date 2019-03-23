import "dart:collection";

import "package:CommonLib/Utility.dart";

import "dice.dart";

class EquatableList<T> extends ListBase<T> {
    List _inner = new List<T>();

    @override
    int get length => _inner.length;

    @override
    void set length(int length) {
        _inner.length = length;
    }

    @override
    void operator[]=(int index, T value) {
        _inner[index] = value;
    }

    @override
    T operator [](int index) => _inner[index];

    @override
    void add(T value) => _inner.add(value);

    @override
    void addAll(Iterable<T> all) => _inner.addAll(all);

    @override
    String toString() => _inner.toString();

    // and now the special stuff

    @override
    bool operator ==(Object other) {
        if (other is EquatableList) {
            if (other.length != this.length) { return false; }

            for (int i=0; i<this.length; i++) {
                if (other[i] != this[i]) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    @override
    int get hashCode {
        int hash = 0;
        for (T item in this) {
            hash ^= item.hashCode;
        }
        return hash ^= length;
    }
}

class SymbolMap extends MapBase<SymbolType,int> {
    Map<SymbolType,int> _inner = <SymbolType,int>{};

    @override
    Iterable<SymbolType> get keys => _inner.keys;

    @override
    int remove(Object key) { _hashDirty = true; return _inner.remove(key); }

    @override
    void clear() { _hashDirty = true; _inner.clear(); }

    @override
    Iterable<int> get values => _inner.values;

    @override
    bool get isNotEmpty => _inner.isNotEmpty;

    @override
    bool get isEmpty => _inner.isEmpty;

    @override
    int get length => _inner.length;

    @override
    bool containsKey(Object key) => _inner.containsKey(key);

    @override
    int putIfAbsent(SymbolType key, int ifAbsent()) { _hashDirty = true; return _inner.putIfAbsent(key, ifAbsent); }

    @override
    bool containsValue(Object value) => _inner.containsValue(value);

    @override
    void addAll(Map<SymbolType, int> other) { _hashDirty = true; _inner.addAll(other); }

    @override
    void forEach(void action(SymbolType key, int value)) => _inner.forEach(action);

    @override
    operator []=(SymbolType key, int value) { _hashDirty = true; _inner[key] = value; }

    @override
    int operator [](Object key) => _inner[key];

    @override
    String toString() => _inner.toString();

    // now the other stuff

    @override
    bool operator ==(Object other) {
        if (identical(this, other)) { return true; }

        if ((other is SymbolMap) && (this.hashCode == other.hashCode)) {
            return true;
        }

        return false;
    }

    bool _hashDirty = true;
    int _hash = null;
    @override
    int get hashCode {
        if (_hashDirty) {
            //print("make hash");
            _hashDirty = false;
            _hash = 0;
            int h;
            for (SymbolType key in this.keys) {
                h = key.hashCode;
                _hash ^= h + h * this[key];
            }
            _hash ^= length;
        } /*else {
            print("use hash");
        }*/
        return _hash;
    }
}

Tuple<int, int> approximateFraction(double number) {
    double startingEpsilon = 0.00002;
    double multiplier = 2.5;
    double limit = 0.1;

    double epsilon = startingEpsilon;
    Tuple<int, int> fraction;
    Tuple<int, int> reducedFraction;
    //print("start: $number");
    while(epsilon < limit) {
        if (fraction != null) {
            reducedFraction = approximateFractionCalc(number, epsilon);

            if (reducedFraction.second == 1 && fraction.second > 1) {
                //print("break: denominator");

                if (fraction.second > 1000) {
                    fraction = reducedFraction; // stops them being really really long
                }

                break;
            }

            fraction = reducedFraction;
        } else {
            fraction = approximateFractionCalc(number, epsilon);
        }

        if (fraction.first < 10) {
            //print("break: numerator");
            break;
        }

        //print("$epsilon -> $fraction");

        epsilon *= multiplier;
    }
    //print("done: $fraction");
    return fraction;
}

Tuple<int, int> approximateFractionCalc(double number, double epsilon) {
    int whole = number.floor();
    double fraction = number - whole;

    if(fraction < epsilon) {
        return new Tuple<int,int>(whole, 1);
    } else if (1 - epsilon < fraction) {
        return new Tuple<int,int>(whole + 1, 1);
    }

    int lowerNumerator = 0;
    int lowerDenominator = 1;

    int upperNumerator = 1;
    int upperDenominator = 1;

    int middleNumerator;
    int middleDenominator;

    while(true) {
        middleNumerator = lowerNumerator + upperNumerator;
        middleDenominator = lowerDenominator + upperDenominator;

        if (middleDenominator * (fraction + epsilon) < middleNumerator) {
            upperNumerator = middleNumerator;
            upperDenominator = middleDenominator;
        } else if (middleNumerator < (fraction - epsilon) * middleDenominator) {
            lowerNumerator = middleNumerator;
            lowerDenominator = middleDenominator;
        } else {
            return new Tuple<int, int>(whole * middleDenominator + middleNumerator, middleDenominator);
        }
    }
}