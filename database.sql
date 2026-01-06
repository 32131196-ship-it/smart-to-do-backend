-- database.sql - MySQL Database Schema for Smart ToDo Planner

-- Create database
CREATE DATABASE IF NOT EXISTS smart_todo;
USE smart_todo;

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id VARCHAR(255) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    priority ENUM('low', 'medium', 'high') DEFAULT 'medium',
    status ENUM('pending', 'completed') DEFAULT 'pending',
    due_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_priority (priority),
    INDEX idx_status (status),
    INDEX idx_due_date (due_date),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- QR Codes table (optional - for tracking QR code generations)
CREATE TABLE IF NOT EXISTS qr_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    task_id VARCHAR(255) NOT NULL,
    qr_data TEXT NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    INDEX idx_task_id (task_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Task History table (optional - for audit trail)
CREATE TABLE IF NOT EXISTS task_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    task_id VARCHAR(255) NOT NULL,
    action ENUM('created', 'updated', 'deleted', 'completed', 'reopened') NOT NULL,
    changed_by VARCHAR(255),
    changes TEXT,
    action_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_task_id (task_id),
    INDEX idx_action_at (action_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data
INSERT INTO tasks (id, title, description, priority, status, due_date) VALUES
('1', 'Complete project proposal', 'Write and submit the Q4 project proposal', 'high', 'pending', DATE_ADD(CURDATE(), INTERVAL 3 DAY)),
('2', 'Team meeting preparation', 'Prepare slides for Monday team meeting', 'medium', 'pending', DATE_ADD(CURDATE(), INTERVAL 1 DAY)),
('3', 'Review code changes', 'Review pull requests from the development team', 'medium', 'pending', CURDATE()),
('4', 'Update documentation', 'Update API documentation with new endpoints', 'low', 'pending', DATE_ADD(CURDATE(), INTERVAL 7 DAY)),
('5', 'Client call follow-up', 'Send follow-up email after client call', 'high', 'completed', CURDATE());

-- Create a view for urgent tasks (due within 3 days)
CREATE OR REPLACE VIEW urgent_tasks AS
SELECT * FROM tasks
WHERE status = 'pending'
  AND due_date IS NOT NULL
  AND due_date <= DATE_ADD(CURDATE(), INTERVAL 3 DAY)
ORDER BY due_date ASC, priority DESC;

-- Create a view for overdue tasks
CREATE OR REPLACE VIEW overdue_tasks AS
SELECT * FROM tasks
WHERE status = 'pending'
  AND due_date IS NOT NULL
  AND due_date < CURDATE()
ORDER BY due_date ASC;

-- Create a view for task statistics
CREATE OR REPLACE VIEW task_statistics AS
SELECT
    COUNT(*) as total_tasks,
    SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_tasks,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
    SUM(CASE WHEN priority = 'high' AND status = 'pending' THEN 1 ELSE 0 END) as high_priority_pending,
    SUM(CASE WHEN due_date = CURDATE() AND status = 'pending' THEN 1 ELSE 0 END) as due_today,
    SUM(CASE WHEN due_date < CURDATE() AND status = 'pending' THEN 1 ELSE 0 END) as overdue
FROM tasks;

-- Stored procedure to mark task as completed
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS complete_task(IN task_id_param VARCHAR(255))
BEGIN
    UPDATE tasks
    SET status = 'completed'
    WHERE id = task_id_param;
    
    INSERT INTO task_history (task_id, action)
    VALUES (task_id_param, 'completed');
END$$
DELIMITER ;

-- Stored procedure to delete old completed tasks
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS cleanup_old_tasks(IN days_old INT)
BEGIN
    DELETE FROM tasks
    WHERE status = 'completed'
      AND updated_at < DATE_SUB(CURDATE(), INTERVAL days_old DAY);
END$$
DELIMITER ;

-- Trigger to log task creation
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS after_task_insert
AFTER INSERT ON tasks
FOR EACH ROW
BEGIN
    INSERT INTO task_history (task_id, action, changes)
    VALUES (NEW.id, 'created', CONCAT('Title: ', NEW.title, ', Priority: ', NEW.priority));
END$$
DELIMITER ;

-- Trigger to log task updates
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS after_task_update
AFTER UPDATE ON tasks
FOR EACH ROW
BEGIN
    DECLARE change_description TEXT;
    SET change_description = '';
    
    IF OLD.title != NEW.title THEN
        SET change_description = CONCAT(change_description, 'Title changed from "', OLD.title, '" to "', NEW.title, '"; ');
    END IF;
    
    IF OLD.status != NEW.status THEN
        SET change_description = CONCAT(change_description, 'Status changed from "', OLD.status, '" to "', NEW.status, '"; ');
    END IF;
    
    IF OLD.priority != NEW.priority THEN
        SET change_description = CONCAT(change_description, 'Priority changed from "', OLD.priority, '" to "', NEW.priority, '"; ');
    END IF;
    
    IF change_description != '' THEN
        INSERT INTO task_history (task_id, action, changes)
        VALUES (NEW.id, 'updated', change_description);
    END IF;
END$$
DELIMITER ;

-- Grant privileges (adjust username as needed)
-- GRANT ALL PRIVILEGES ON smart_todo.* TO 'your_user'@'localhost';
-- FLUSH PRIVILEGES;