#!/usr/bin/env bash
set -euo pipefail

read -rp "Nhập tên entity (PascalCase, ví dụ: ServiceRegistry): " name
[[ -z "$name" ]] && { echo "❌ Entity name không được rỗng"; exit 1; }

ENT_DIR="src/databases/postgres/entities"
REPO_DIR="src/repositories"
SRV_DIR="src/services"
TYPES_DIR="src/services/types"
CTRL_DIR="src/rests/controllers"
DTO_DIR="src/rests/types"

mkdir -p "$ENT_DIR" "$REPO_DIR" "$SRV_DIR" "$TYPES_DIR" "$CTRL_DIR" "$DTO_DIR"

# lowerCamelCase cho biến repo: serviceRegistryRepo
first="${name:0:1}"; rest="${name:1}"
lcFirst="$(tr '[:upper:]' '[:lower:]' <<<"$first")"
varRepo="${lcFirst}${rest}Repo"

# kebab-case + 's' cho base route
kebab="$(sed -e 's/\([^A-Z]\)\([A-Z]\)/\1-\L\2/g' -e 's/^\([A-Z]\)/\L\1/' <<<"$name" | tr '[:upper:]' '[:lower:]')"
routeBase="${kebab}s"

entityPath="$ENT_DIR/${name}.ts"
repoPath="$REPO_DIR/${name}Repository.ts"
srvPath="$SRV_DIR/${name}Service.ts"
typesPath="$TYPES_DIR/${name}Input.ts"
ctrlPath="$CTRL_DIR/${name}Controller.ts"
dtoPath="$DTO_DIR/${name}Dto.ts"

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

# --- Services/types (Create/Update only; QueryParams chuyển sang Rests/types theo yêu cầu) ---
if [[ ! -f "$typesPath" ]]; then
  cat > "$typesPath" <<EOF
import type { ${name} } from '@Entities/${name}';

export type Create${name}Input = Partial<Omit<${name}, 'id' | 'createdAt' | 'updatedAt'>>;
export type Update${name}Input = Partial<Omit<${name}, 'id' | 'createdAt' | 'updatedAt'>>;
EOF
  echo "✅ Created $typesPath"
else
  echo "⚠️  Skipped $typesPath (already exists)"
fi

# --- Rests/types (DTO + QueryParams) ---
if [[ ! -f "$dtoPath" ]]; then
  cat > "$dtoPath" <<EOF
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { BaseQueryParams } from '@Rests/types/common/BaseQueryParams';

export class ${name}QueryParams extends BaseQueryParams {}

export class Create${name}Dto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  name!: string;
}

export class Update${name}Dto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  name?: string;
}
EOF
  echo "✅ Created $dtoPath"
else
  echo "⚠️  Skipped $dtoPath (already exists)"
fi

# --- Service (nhận ${name}QueryParams từ Rests/types) ---
if [[ ! -f "$srvPath" ]]; then
  cat > "$srvPath" <<EOF
import { Service } from 'typedi';
import { FindOneOptions, ILike, FindOptionsWhere, FindManyOptions } from 'typeorm';

import { ${name} } from '@Entities/${name}';
import { ${name}Repository } from '@Repositories/${name}Repository';

import { Create${name}Input, Update${name}Input } from '@Services/types/${name}Input';
import { ${name}QueryParams } from '@Rests/types/${name}Dto';
import { HttpPaginatedResponse } from '@Libs/types/HttpPaginatedResponse';

@Service()
export class ${name}Service {
  constructor(
    private readonly ${varRepo}: ${name}Repository,
  ) {}

  async findAllPaginated(params: ${name}QueryParams): Promise<HttpPaginatedResponse<${name}>> {
    const { page = 1, size = 10, searchText, sortBy = 'id', sortDirection = 'ASC' } = params;
    const skip = (page - 1) * size;

    let where: FindOptionsWhere<${name}> | FindOptionsWhere<${name}>[] = {};
    if (searchText) {
      where = { name: ILike(\`%\${searchText}%\`) };
    }

    const options: FindManyOptions<${name}> = {
      where,
      skip,
      take: size,
      order: { [sortBy]: sortDirection as 'ASC' | 'DESC' },
    };

    const [items, total] = await this.${varRepo}.findAndCount(options);

    return new HttpPaginatedResponse<${name}>()
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

# --- Controller (dùng ${name}QueryParams) ---
if [[ ! -f "$ctrlPath" ]]; then
  cat > "$ctrlPath" <<EOF
import { JsonController, Get, Post, Put, Delete, Param, Body, QueryParams, OnUndefined } from 'routing-controllers';
import { OpenAPI } from 'routing-controllers-openapi';
import { Service } from 'typedi';

import { ${name} } from '@Entities/${name}';
import { ${name}Service } from '@Services/${name}Service';
import { ${name}QueryParams, Create${name}Dto, Update${name}Dto } from '@Rests/types/${name}Dto';
import { HttpPaginatedResponse } from '@Libs/types/HttpPaginatedResponse';

@Service()
@JsonController('/${routeBase}')
export class ${name}Controller {
  constructor(private readonly service: ${name}Service) {}

  @Get('')
  @OpenAPI({ summary: 'List ${name} (paginated)' })
  list(@QueryParams() params: ${name}QueryParams): Promise<HttpPaginatedResponse<${name}>> {
    return this.service.findAllPaginated(params);
  }

  @Get('/:id')
  @OpenAPI({ summary: 'Get ${name} by id' })
  get(@Param('id') id: number) {
    return this.service.findById(id);
  }

  @Post('')
  @OpenAPI({ summary: 'Create ${name}' })
  create(@Body({ validate: true }) dto: Create${name}Dto) {
    return this.service.create(dto);
  }

  @Put('/:id')
  @OpenAPI({ summary: 'Update ${name}' })
  update(@Param('id') id: number, @Body({ validate: true }) dto: Update${name}Dto) {
    return this.service.update(id, dto);
  }

  @Delete('/:id')
  @OnUndefined(204)
  @OpenAPI({ summary: 'Delete ${name}' })
  remove(@Param('id') id: number) {
    return this.service.delete(id);
  }
}
EOF
  echo "✅ Created $ctrlPath"
else
  echo "⚠️  Skipped $ctrlPath (already exists)"
fi

echo "🎉 Entity ${name} scaffolded (Entity/Repo/Types/Service/DTO/Controller)!"
