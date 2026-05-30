package {{PACKAGE_NAME}}.application.port.in;

import {{PACKAGE_NAME}}.domain.model.Item;

import java.util.List;
import java.util.UUID;

public interface ItemUseCase {

    Item create(String name, String description);

    Item findById(UUID id);

    List<Item> findAll();

    Item update(UUID id, String name, String description);

    void delete(UUID id);
}
