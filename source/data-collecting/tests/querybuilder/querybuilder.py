class QueryCondition:
    def __init__(self, colname, value):
        self.colname = colname
        self.value = value

    def __str__(self):
        return '{0} = {1}'.format(
            self.colname,
            str(self.value)
            if not isinstance(self.value, str)
            else "'" + self.value + "'"
        )


class QueryBuilder:
    def get_query_conditions(self, condition_colnames, record):
        return list(
            map(
                lambda col: QueryCondition(col, record[col]),
                condition_colnames
            )
        )

    def get_condition_statement(self, grouped_query_conditions):
        grouped_statements = list(map(
            lambda group: '(' + ' AND '.join(list(map(str, group))) + ')',
            grouped_query_conditions
        ))
        if len(grouped_statements):
            return ' OR '.join(grouped_statements)
        else:
            return grouped_statements[0]

    def get_select_query(self, colnames, tablename, condition_colnames, grouped_query_conditions):
        statement = '''
            SELECT {colnames} FROM {tablename}
            WHERE {condition}
            ORDER BY {condition_colnames}
        '''.format(
            tablename=tablename,
            colnames=', '.join(colnames),
            condition=self.get_condition_statement(grouped_query_conditions),
            condition_colnames=', '.join(condition_colnames)
        )
        return ' '.join(statement.split())
