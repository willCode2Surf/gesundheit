common = require './common'
[AND, OR, JOIN_TYPES] = ['AND', 'OR', 'JOIN_TYPES'].map((k) -> common[k])

PLACEHOLDER = '?'
DEFAULT_JOIN = JOIN_TYPES.INNER


exports.renderSelect = (qs) ->
	ret = "SELECT #{fields qs} FROM " + [
		joins, where, group, order, limit
	].map((f) -> f qs).join ''

fields = (qs) ->
	fs = []
	for tbl, tbl_fields of qs.fields
		continue unless tbl_fields?
		if tbl_fields.length
			tbl_fields.forEach (f) ->
				fs.push "#{tbl}.#{f}"
		else
			fs.push "#{tbl}.*"
	fs.join ', '

joins = exports.joins = (qs) ->
	i = 0
	tables = for [table, alias, type, clause] in qs.tableStack
		continue if type == 'NOP'

		ret = if i++ then "#{type.toUpperCase()} JOIN #{table}" else table

		if table != alias then ret += " AS #{alias}"
		if clause? then ret += " ON #{renderClause clause, (v) -> v}"
		ret
	tables.join ' '

where = exports.where = (qs) ->
	if qs.where.length then " WHERE #{renderClause qs.where}" else ""

group = exports.group = (qs) ->
	if qs.groupings.length
		" GROUP BY #{qs.groupings.map((g) -> g.table+'.'+g.field).join ', '}"
	else ""

order = exports.order = (qs) -> 
	if qs.order.length
		' ORDER BY ' + qs.order.map((o) -> 
			o.table+'.'+o.field + if o.direction then ' '+o.direction else ''
		).join ', '
	else ""

# TODO - parseInt
limit = (qs) -> if qs.limit? then " LIMIT #{qs.limit}" else ""

renderBoundParam = (v) ->
	if v and v.constructor == Array then "(#{v.map(-> PLACEHOLDER).join ', '})"
	else PLACEHOLDER

exports.renderClause = renderClause = (input, renderValue=renderBoundParam) ->
	render = (clause) ->
		if clause? and clause.constructor == Array
			"#{clause.map(render).join(' AND ')}"
		else if typeof clause == 'object'
			if clause.op == 'multi'
				"(#{clause.clauses.map(render).join(clause.glue)})"
			else
				"#{clause.table}.#{clause.field} #{clause.op} #{renderValue clause.value}"
		else
			throw new Error "Unexpected clause type, this is probably a bug"
	render input

# TODO - check whether there is any difference in the supported comparison operators
exports.joinOp = exports.whereOp = (op) ->
	switch op.toLowerCase()
		when 'ne', '!=', '<>' then '!='
		when 'eq', '='   then '='
		when 'lt', '<'   then '<'
		when 'gt', '>'   then '>'
		when 'lte', '<=' then '<='
		when 'gte', '>=' then '>='
		when 'in' then 'IN'
		else throw new Error("Unsupported comparison operator: #{op}")

exports.joinType = (type) ->
	return 'INNER' unless type
	type = type.toUpperCase()
	if type in JOIN_TYPES then type
	else throw new Error "Unsupported JOIN type #{type}"
