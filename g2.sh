#!/usr/bin/env bash
set -euo pipefail

read -rp "Nhập tên entity (PascalCase, ví dụ: File): " name

if [[ -z "$name" ]]; then
  echo "❌ Entity name không được rỗng"
  exit 1
fi

ENT_DIR="src/databases/postgres/entities"
REPO_DIR="src/repositories"
SRV_DIR="src/services"
TYPES_DIR="src/services/types"

mkdir -p "$ENT_DIR" "$REPO_DIR" "$SRV_DIR" "$TYPES_DIR"

# lowerCamelCase cho tên biến repo: fileRepo
first="${name:0:1}"
rest="${name:1}"
lcFirst="$(tr '[:upper:]' '[:lower:]' <<<"$first")"
varRepo="${lcFirst}${rest}Repo"

entityPath="$ENT_DIR/${name}.ts"
repoPath="$REPO_DIR/${name}Repository.ts"
srvPath="$SRV_DIR/${name}Service.ts"
typesPath="$TYPES_DIR/${name}Input.ts"

# --- Entity ---
if [[ ! -f "$entityPath" ]]; then
  cat > "$entityPath" <<EOF
import { Entity, Column } from 'typeorm';
import { BaseEntity } from '@DBCommon/BaseEntity';

@Entity()
export class ${name} extends BaseEntity {
  @Column({ type: 'varchar', length: 255 })
  name!: string;
}
EOF
  echo "✅ Created $entityPath"
else
  echo "⚠️  Skipped $entityPath (already exists)"
fi

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

# --- Types ---
if [[ ! -f "$typesPath" ]]; then
  cat > "$typesPath" <<EOF
import type { ${name} } from '@Entities/${name}';
import { BaseQueryParamInput } from '@Services/types/common/BaseQueryParamInput';

export class ${name}QueryParamInput extends BaseQueryParamInput {
  /** Tuỳ entity: sửa field search cho phù hợp (name/title/code/...) */
  searchText?: string;
}

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
import { FindOneOptions, ILike } from 'typeorm';

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

    const where: any = {};
    if (searchText) {
      where.name = ILike(\`%\${searchText}%\`);
    }

    const options = {
      where,
      skip,
      take: size,
      order: { [sortBy]: sortDirection as 'ASC' | 'DESC' },
    } as const;

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

echo "🎉 Entity ${name} scaffolded successfully!"
