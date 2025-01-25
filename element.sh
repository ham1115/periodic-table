#!/bin/bash
PSQL="psql -X --username=freecodecamp --dbname=periodic_table --tuples-only -c"

main() {
  if [[ -z $1 ]]; then
    echo "Please provide an element as an argument."
  else
    display_element "$1"
  fi
}

display_element() {
  local input="$1"
  if [[ $input =~ ^[0-9]+$ ]]; then
    atomic_number=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE atomic_number=$input;") | xargs)
  else
    atomic_number=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE symbol='$input' OR name='$input';") | xargs)
  fi

  if [[ -z $atomic_number ]]; then
    echo "Element not found in the database."
  else
    name=$(echo $($PSQL "SELECT name FROM elements WHERE atomic_number=$atomic_number;") | xargs)
    symbol=$(echo $($PSQL "SELECT symbol FROM elements WHERE atomic_number=$atomic_number;") | xargs)
    type=$(echo $($PSQL "SELECT type FROM types JOIN properties USING(type_id) WHERE atomic_number=$atomic_number;") | xargs)
    atomic_mass=$(echo $($PSQL "SELECT atomic_mass FROM properties WHERE atomic_number=$atomic_number;") | xargs)
    melting_point=$(echo $($PSQL "SELECT melting_point_celsius FROM properties WHERE atomic_number=$atomic_number;") | xargs)
    boiling_point=$(echo $($PSQL "SELECT boiling_point_celsius FROM properties WHERE atomic_number=$atomic_number;") | xargs)

    echo "The element with atomic number $atomic_number is $name ($symbol). It's a $type with a mass of $atomic_mass amu. $name has a melting point of $melting_point°C and a boiling point of $boiling_point°C."
  fi
}

fix_database() {
  $PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;"
  $PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;"
  $PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;"
  $PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;"
  $PSQL "ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;"
  $PSQL "ALTER TABLE elements ADD UNIQUE(symbol);"
  $PSQL "ALTER TABLE elements ADD UNIQUE(name);"
  $PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;"
  $PSQL "ALTER TABLE elements ALTER COLUMN name SET NOT NULL;"
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY (atomic_number) REFERENCES elements(atomic_number);"

  $PSQL "CREATE TABLE IF NOT EXISTS types(type_id SERIAL PRIMARY KEY, type VARCHAR(20) NOT NULL);"
  $PSQL "INSERT INTO types(type) SELECT DISTINCT type FROM properties ON CONFLICT DO NOTHING;"
  $PSQL "ALTER TABLE properties ADD COLUMN type_id INT;"
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY (type_id) REFERENCES types(type_id);"
  $PSQL "UPDATE properties SET type_id = (SELECT type_id FROM types WHERE properties.type = types.type);"
  $PSQL "ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;"

  $PSQL "UPDATE elements SET symbol = INITCAP(symbol);"
  $PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE DECIMAL(9, 3) USING atomic_mass::DECIMAL;"
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES (9, 'F', 'Fluorine') ON CONFLICT DO NOTHING;"
  $PSQL "INSERT INTO properties(atomic_number, type_id, melting_point_celsius, boiling_point_celsius, atomic_mass) VALUES (9, 3, -220, -188.1, 18.998) ON CONFLICT DO NOTHING;"
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES (10, 'Ne', 'Neon') ON CONFLICT DO NOTHING;"
  $PSQL "INSERT INTO properties(atomic_number, type_id, melting_point_celsius, boiling_point_celsius, atomic_mass) VALUES (10, 3, -248.6, -246.1, 20.18) ON CONFLICT DO NOTHING;"
  $PSQL "DELETE FROM properties WHERE atomic_number = 1000;"
  $PSQL "DELETE FROM elements WHERE atomic_number = 1000;"
}

main "$@"
