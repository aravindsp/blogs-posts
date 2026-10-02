{# Drop every schema this project built for the current CI run
   (e.g. CI_PR_42_STAGING, CI_PR_42_MARTS, CI_PR_42_SNAPSHOTS). #}
{% macro drop_ci_schemas() %}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas only runs on the ci target") }}
    {% endif %}
    {% set schemas = [] %}
    {% for node in graph.nodes.values() %}
        {% if node.resource_type in ['model', 'snapshot', 'seed']
              and node.schema | upper is not in schemas
              and (node.schema | upper).startswith(target.schema | upper) %}
            {% do schemas.append(node.schema | upper) %}
        {% endif %}
    {% endfor %}
    {% for schema in schemas %}
        {% do adapter.drop_schema(api.Relation.create(database=target.database, schema=schema)) %}
        {{ log("Dropped schema " ~ schema, info=True) }}
    {% endfor %}
{% endmacro %}
