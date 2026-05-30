package {{PACKAGE_NAME}}.infrastructure.persistence;

import {{PACKAGE_NAME}}.domain.model.Item;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

interface ItemJpaRepository extends JpaRepository<Item, UUID> {
}
