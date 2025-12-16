#!/usr/bin/env bash
set -euo pipefail

ENT_DIR="src/databases/postgres/entities"
REPO_DIR="src/repositories"
SRV_DIR="src/services"
TYPES_DIR="src/services/types"

mkdir -p "$REPO_DIR" "$SRV_DIR" "$TYPES_DIR"

shopt -s nullglob
for entity in "$ENT_DIR"/*.ts; do
  name="$(basename "$entity" .ts)"   # Entity name, vd: ServiceRegistry

  # lowerCamelCase cho tên biến repo: serviceRegistryRepo
  first="${name:0:1}"
  rest="${name:1}"
  lcFirst="$(tr '[:upper:]' '[:lower:]' <<<"$first")"
  varRepo="${lcFirst}${rest}Repo"

  repoPath="$REPO_DIR/${name}Repository.ts"
  srvPath="$SRV_DIR/${name}Service.ts"
  typesPath="$TYPES_DIR/${name}Input.ts"

  # --- Repository ---
  if [[ ! -f "$repoPath" ]]; then
    cat > "$repoPath" <<EOF
import { Inject, Service } from 'typedi';
import { DataSource } from 'typeorm';

import { ${name} } from '@Entities/${name}';
import { BaseOrmRepository } from '@Repositories/BaseOrmRepository';

@Service()
export class ${name}Repository extends BaseOrmRepository<${name}> {
  constructor(@Inject('dataSource') dataSource: DataSource) {
    super(dataSource, ${name});
  }
}
EOF
    echo "✅ Created $repoPath"
  else
    echo "⚠️  Skipped $repoPath (already exists)"
  fi

  # --- Types (Create/Update + QueryParamInput) ---
  if [[ ! -f "$typesPath" ]]; then
    cat > "$typesPath" <<EOF
import { ${name} } from '@Entities/${name}';

import { BaseQueryParamInput } from '@Services/types/common/BaseQueryParamInput';

export class ${name}QueryParamInput extends BaseQueryParamInput {}

export type Create${name}Input = Partial<Omit<${name}, 'id' | 'createdAt' | 'updatedAt'>>;
export type Update${name}Input = Partial<Omit<${name}, 'id' | 'createdAt' | 'updatedAt'>>;
EOF
    echo "✅ Created $typesPath"
  else
    echo "⚠️  Skipped $typesPath (already exists)"
  fi

  # --- Service ---
  if [[ ! -f "$srvPath" ]]; then
    cat > "$srvPath" <<EOF
import { Service } from 'typedi';
import { FindOneOptions, FindManyOptions, ILike } from 'typeorm';

import { ${name} } from '@Entities/${name}';
import { ${name}Repository } from '@Repositories/${name}Repository';

import { Create${name}Input, Update${name}Input, ${name}QueryParamInput } from '@Services/types/${name}Input';
import { HttpPaginatedResponse } from '@Libs/types/HttpPaginatedResponse';

@Service()
export class ${name}Service {
  constructor(
    private readonly ${varRepo}: ${name}Repository,
  ) {}

  async findAllPaginated(params: ${name}QueryParamInput) {
    const { page = 1, size = 10, searchText, sortBy = 'id', sortDirection = 'ASC' } = params;
    const skip = (page - 1) * size;

    const where: FindManyOptions<${name}>['where'] = {};
    if (searchText) {
      
      where['name'] = ILike(\`%\${searchText}%\`);
    }

    const options: FindManyOptions<${name}> = {
      where,
      skip,
      take: size,
      order: { [sortBy]: sortDirection as 'ASC' | 'DESC' },
    };

    const [items, total] = await this.${varRepo}.findAndCount(options);

    return new HttpPaginatedResponse()
      .withItems(items)
      .withTotal(total)
      .withPage(page)
      .withSize(size);
  }

  findAll() {
    return this.${varRepo}.findAndCount();
  }

  findById(id: number) {
    return this.${varRepo}.findOne({ where: { id } });
  }

  async create(data: Create${name}Input) {
    const entity = new ${name}();
    Object.assign(entity, data);
    return this.${varRepo}.insert(entity);
  }

  async update(id: number, data: Update${name}Input) {
    await this.${varRepo}.updateById(id, data);
    return this.findById(id);
  }

  delete(id: number) {
    return this.${varRepo}.delete(id);
  }

  findOne(options: FindOneOptions<${name}>) {
    return this.${varRepo}.findOne(options);
  }
}
EOF
    echo "✅ Created $srvPath"
  else
    echo "⚠️  Skipped $srvPath (already exists)"
  fi

done
echo "🎉 All done!"
