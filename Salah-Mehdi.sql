USE restaurant;
DELIMITER //

CREATE PROCEDURE clientRegistration(
    IN nom VARCHAR(255), 
    IN prenom VARCHAR(255), 
    IN email VARCHAR(255), 
    IN telephone VARCHAR(255)
)
BEGIN
    INSERT INTO clients (nom, prenom, email, telephone) 
    VALUES (nom, prenom, email, telephone);
END//
DELIMITER ;

CALL clientRegistration('salah', 'our', 'salahor20@gmail.com', '062043');

DELIMITER //
CREATE PROCEDURE ajout_paiement_acompte(
    IN id_reservation INT, 
    IN montant DECIMAL(10,2)
)
BEGIN
    UPDATE reservations 
    SET acompte = montant 
    WHERE id = id_reservation;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE createReservation(
    IN r_id_client INT,
    IN r_date_reservation DATE,
    IN r_heure_reservation TIME,
    IN r_nbr_personnes INT,
    IN r_emplacement VARCHAR(20)
)
BEGIN 
    DECLARE new_reservation_id INT;
    
    INSERT INTO reservations (id_client, date_reservation, heure_reservation, nb_personnes, acompte, emplacement) 
    VALUES (r_id_client, r_date_reservation, r_heure_reservation, r_nbr_personnes, 0, r_emplacement); 
    
    SET new_reservation_id = LAST_INSERT_ID();
    CALL ajout_paiement_acompte(new_reservation_id, r_nbr_personnes * 10);
    CALL assignTable(new_reservation_id, r_emplacement, r_nbr_personnes, r_date_reservation, r_heure_reservation);
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE assignTable(
    IN reservation_id INT,
    IN emplacement VARCHAR(20),
    IN nbr_personnes INT,
    IN date_reservation DATE,
    IN heure_reservation TIME
)
BEGIN
    DECLARE table_id INT;
    
    SELECT id INTO table_id
    FROM tables
    WHERE emplacement = emplacement
    AND capacite >= nbr_personnes
    AND NOT EXISTS (
        SELECT 1
        FROM reservations
        WHERE date_reservation = date_reservation
        AND id_table = tables.id
        AND NEW.heure_reservation < ADDTIME(heure_reservation, '1:30:00')
        AND ADDTIME(NEW.heure_reservation, '1:30:00') > heure_reservation
    )
    LIMIT 1;

    IF table_id IS NOT NULL THEN
        UPDATE reservations
        SET id_table = table_id
        WHERE id = reservation_id;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aucune table disponible pour la réservation à cet emplacement et à cette heure.';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER VerifierReservation 
BEFORE INSERT ON reservations
FOR EACH ROW
BEGIN
    IF NEW.heure_reservation < '19:00:00' OR NEW.heure_reservation > '23:00:00' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Horaire de réservation non valide.';
    END IF;
END//
DELIMITER ;

CALL createReservation(1, '2024-05-01', '21:50:00', 8, 'salle');

DELIMITER //
CREATE PROCEDURE ajout_paiement_solde(
    IN r_id_reservation INT,
    IN r_montant_total DECIMAL(10,2)
)
BEGIN
    DECLARE r_acompte DECIMAL(10,2);
    SELECT acompte INTO r_acompte 
    FROM reservations 
    WHERE id = r_id_reservation;
    
    INSERT INTO paiements(id_reservation, montant, date_paiement) 
    VALUES (r_id_reservation, r_montant_total - r_acompte, NOW());
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER ajout_solde_reservation 
AFTER INSERT ON paiements
FOR EACH ROW 
BEGIN
    UPDATE reservations 
    SET solde = NEW.montant 
    WHERE id = NEW.id_reservation;
END//
DELIMITER ;
